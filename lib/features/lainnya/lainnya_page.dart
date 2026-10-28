import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/security_service.dart';
import '../../data/backup_service.dart';
import '../../data/repository.dart';
import '../anggaran/anggaran_page.dart';
import '../kategori/kelola_kategori_page.dart';
import '../keamanan/kelola_keamanan_page.dart';
import '../master/master_bahasa_page.dart';
import '../tag/kelola_tag_page.dart';
import '../tagihan/tagihan_page.dart';
import '../target/target_page.dart';

enum CsvPeriodMode { all, thisMonth, thisYear, custom }

class LainnyaPage extends StatefulWidget {
  const LainnyaPage({super.key});

  @override
  State<LainnyaPage> createState() => _LainnyaPageState();
}

class _LainnyaPageState extends State<LainnyaPage> {
  bool _isLoading = false;
  String _loadingMessage = '';

  // Pengaturan Ekspor CSV
  CsvPeriodMode _csvMode = CsvPeriodMode.all;
  String _csvSeparator = ';'; // Standar Excel Indonesia
  DateTimeRange? _customRange;

  void _setLoading(bool loading, [String message = '']) {
    setState(() {
      _isLoading = loading;
      _loadingMessage = message;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ----------------------------------------------------------- CADANGAN DATA
  Future<void> _backupAndShare(BackupService service) async {
    try {
      _setLoading(true, 'Menyiapkan berkas cadangan...');
      await service.exportAndShareBackup();
      _showSnack('Cadangan berhasil dibuat!');
    } catch (e) {
      _showSnack('Gagal membuat cadangan: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _copyBackupJson(BackupService service) async {
    try {
      _setLoading(true, 'Menyalin data...');
      final jsonStr = await service.exportBackupJson();
      await Clipboard.setData(ClipboardData(text: jsonStr));
      _showSnack('Teks cadangan berhasil disalin ke Clipboard!');
    } catch (e) {
      _showSnack('Gagal menyalin cadangan: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------- PEMULIHAN DATA
  Future<void> _pickAndRestore(BackupService service) async {
    try {
      final jsonStr = await service.pickBackupFile();
      if (jsonStr == null || !mounted) return;

      _confirmAndExecuteRestore(service, jsonStr);
    } catch (e) {
      _showSnack('Gagal membaca berkas cadangan: $e', isError: true);
    }
  }

  Future<void> _pasteAndRestore(BackupService service) async {
    final textCtrl = TextEditingController();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null &&
        (data!.text!.contains('finku') ||
            data.text!.contains('keuangan_saku'))) {
      textCtrl.text = data.text!;
    }

    if (!mounted) return;
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tempel Teks Cadangan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempelkan isi teks JSON cadangan yang telah disalin sebelumnya:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{"app": "keuangan_saku", ...}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );

    if (submitted == null || submitted.isEmpty || !mounted) return;
    _confirmAndExecuteRestore(service, submitted);
  }

  Future<void> _confirmAndExecuteRestore(
    BackupService service,
    String jsonStr,
  ) async {
    try {
      final summary = service.validateBackup(jsonStr);

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Konfirmasi Pemulihan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan data dalam berkas cadangan:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _summaryRow('Waktu Cadangan', tglPanjang(summary.createdAt)),
              _summaryRow(
                  'Total Transaksi', '${summary.transactionCount} transaksi'),
              _summaryRow('Jumlah Aset/Akun', '${summary.assetCount} aset'),
              _summaryRow('Kategori', '${summary.categoryCount} kategori'),
              _summaryRow('Tag / Label', '${summary.tagCount} tag'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PENTING: Seluruh data transaksi, aset, dan kategori yang ada saat ini akan DIGANTIKAN oleh data cadangan ini.',
                        style: TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pulihkan Sekarang'),
            ),
          ],
        ),
      );

      if (ok != true || !mounted) return;

      _setLoading(true, 'Memulihkan data...');
      await service.restoreFromJson(jsonStr);
      _showSnack('Data berhasil dipulihkan!');
    } catch (e) {
      _showSnack('Gagal memulihkan data: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ------------------------------------------------------- EKSPOR EXCEL / CSV
  Future<void> _exportCsv(BackupService service) async {
    try {
      DateTime? from;
      DateTime? to;
      final now = DateTime.now();

      switch (_csvMode) {
        case CsvPeriodMode.all:
          from = DateTime(2000);
          to = DateTime(2100);
          break;
        case CsvPeriodMode.thisMonth:
          from = firstOfMonth(now);
          to = lastOfMonth(now);
          break;
        case CsvPeriodMode.thisYear:
          from = DateTime(now.year, 1, 1);
          to = DateTime(now.year, 12, 31);
          break;
        case CsvPeriodMode.custom:
          if (_customRange != null) {
            from = _customRange!.start;
            to = _customRange!.end;
          } else {
            from = DateTime(2000);
            to = DateTime(2100);
          }
          break;
      }

      _setLoading(true, 'Membuat berkas CSV / Excel...');
      await service.exportAndShareCsv(
        from: from,
        to: to,
        separator: _csvSeparator,
      );
      _showSnack('Berkas CSV / Excel berhasil dibuat!');
    } catch (e) {
      _showSnack('Gagal ekspor CSV: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _csvMode = CsvPeriodMode.custom;
        _customRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final service = BackupService(repo);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lainnya'.tr),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ------------------------------------------ CARD 1: BACKUP & RESTORE
              _sectionTitle(
                  'Cadangan & Pemulihan Data'.tr, Icons.backup_outlined),
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cadangkan data secara rutin agar data Anda tetap aman saat ganti ponsel atau jika aplikasi terhapus.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      // Tombol Cadangkan
                      FilledButton.icon(
                        onPressed:
                            _isLoading ? null : () => _backupAndShare(service),
                        icon: const Icon(Icons.upload_file),
                        label: Text('Cadangkan Data ke File'.tr),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Opsi Salin JSON
                      OutlinedButton.icon(
                        onPressed:
                            _isLoading ? null : () => _copyBackupJson(service),
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text('Salin Teks Cadangan (JSON)'.tr),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                        ),
                      ),
                      const Divider(height: 28),
                      // Pemulihan Data
                      Text(
                        'Pulihkan Data dari Cadangan:'.tr,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _pickAndRestore(service),
                              icon: const Icon(Icons.folder_open, size: 18),
                              label: const Text('Pilih Berkas'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _pasteAndRestore(service),
                              icon: const Icon(Icons.paste, size: 18),
                              label: const Text('Tempel Teks'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------ CARD 2: EXPORT EXCEL & CSV
              _sectionTitle(
                  'Ekspor ke Excel & CSV', Icons.table_chart_outlined),
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ekspor seluruh catatan transaksi ke dalam format berkas CSV yang dapat langsung dibuka di Microsoft Excel atau Google Sheets.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 14),

                      // Filter Periode
                      const Text(
                        'Periode Transaksi:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua'),
                            selected: _csvMode == CsvPeriodMode.all,
                            onSelected: (_) =>
                                setState(() => _csvMode = CsvPeriodMode.all),
                          ),
                          ChoiceChip(
                            label: const Text('Bulan Ini'),
                            selected: _csvMode == CsvPeriodMode.thisMonth,
                            onSelected: (_) => setState(
                                () => _csvMode = CsvPeriodMode.thisMonth),
                          ),
                          ChoiceChip(
                            label: const Text('Tahun Ini'),
                            selected: _csvMode == CsvPeriodMode.thisYear,
                            onSelected: (_) => setState(
                                () => _csvMode = CsvPeriodMode.thisYear),
                          ),
                          ChoiceChip(
                            label: Text(
                              _customRange != null
                                  ? '${tglPendek(_customRange!.start)} - ${tglPendek(_customRange!.end)}'
                                  : 'Pilih Tanggal',
                            ),
                            selected: _csvMode == CsvPeriodMode.custom,
                            onSelected: (_) => _pickCustomRange(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Pemisah Kolom (Separator)
                      const Text(
                        'Pemisah Kolom (Delimiter):',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Excel ID'),
                            selected: _csvSeparator == ';',
                            onSelected: (_) =>
                                setState(() => _csvSeparator = ';'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Internasional'),
                            selected: _csvSeparator == ',',
                            onSelected: (_) =>
                                setState(() => _csvSeparator = ','),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Tombol Ekspor
                      FilledButton.icon(
                        onPressed:
                            _isLoading ? null : () => _exportCsv(service),
                        icon: const Icon(Icons.share),
                        label: const Text('Ekspor & Bagikan Berkas CSV'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------ CARD 3: ANGGARAN & TAGIHAN
              _sectionTitle('Perencanaan Keuangan'.tr, Icons.savings_outlined),
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.withValues(alpha: 0.15),
                        child:
                            const Icon(Icons.flag_outlined, color: Colors.teal),
                      ),
                      title: Text('Target Menabung (Goals)'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Kumpulkan dana impian, pantau progress, dan alokasi tabungan'
                              .tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TargetPage()),
                      ),
                    ),
                    Divider(
                        height: 1,
                        indent: 64,
                        color: isDark ? Colors.white12 : Colors.black12),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.withValues(alpha: 0.15),
                        child:
                            const Icon(Icons.track_changes, color: Colors.teal),
                      ),
                      title: Text('Anggaran Pengeluaran'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Batas pengeluaran per kategori & pantau sisa anggaran bulanan'
                              .tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AnggaranPage()),
                      ),
                    ),
                    Divider(
                        height: 1,
                        indent: 64,
                        color: isDark ? Colors.white12 : Colors.black12),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Colors.orangeAccent.withValues(alpha: 0.15),
                        child: const Icon(Icons.event_repeat_outlined,
                            color: Colors.orangeAccent),
                      ),
                      title: Text('Transaksi Berulang & Tagihan'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Langganan rutin, cicilan, dan pengingat jatuh tempo'
                              .tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TagihanPage()),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------ CARD 4: KELOLA MASTER DATA
              _sectionTitle('Kelola Master Data'.tr, Icons.tune),
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Icon(Icons.category_outlined,
                            color: theme.colorScheme.primary),
                      ),
                      title: Text('Kelola Kategori'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Ubah nama, warna, hapus, dan urutkan kategori'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const KelolaKategoriPage()),
                      ),
                    ),
                    Divider(
                        height: 1,
                        indent: 64,
                        color: isDark ? Colors.white12 : Colors.black12),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.secondary.withValues(alpha: 0.15),
                        child: Icon(Icons.label_outlined,
                            color: theme.colorScheme.secondary),
                      ),
                      title: Text('Kelola Tag'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Ubah nama (koreksi salah ketik) atau hapus tag'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const KelolaTagPage()),
                      ),
                    ),
                    Divider(
                        height: 1,
                        indent: 64,
                        color: isDark ? Colors.white12 : Colors.black12),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withValues(alpha: 0.15),
                        child: const Icon(Icons.translate_outlined,
                            color: Colors.blue),
                      ),
                      title: Text('Master Bahasa'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${AppSettings.instance.currentLanguage.flag} ${AppSettings.instance.currentLanguage.name}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MasterBahasaPage()),
                        );
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------ CARD 5: KEAMANAN & PRIVASI
              _sectionTitle('Keamanan & Privasi Data'.tr, Icons.security),
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: SecurityService.instance.isLockEnabled
                            ? Colors.teal.withValues(alpha: 0.15)
                            : (isDark ? Colors.white12 : Colors.black12),
                        child: Icon(
                          SecurityService.instance.isLockEnabled
                              ? Icons.lock
                              : Icons.lock_open,
                          color: SecurityService.instance.isLockEnabled
                              ? Colors.teal
                              : Colors.grey,
                        ),
                      ),
                      title: Text('Kunci Aplikasi (PIN & Sidik Jari)'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        SecurityService.instance.isLockEnabled
                            ? (SecurityService.instance.isBiometricEnabled &&
                                    SecurityService.instance.hasBiometrics
                                ? 'Aktif (PIN & Sidik Jari)'
                                : 'Aktif (PIN)')
                            : 'Nonaktif - Pasang kunci pengaman',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const KelolaKeamananPage()),
                        );
                        setState(() {});
                      },
                    ),
                    Divider(
                        height: 1,
                        indent: 64,
                        color: isDark ? Colors.white12 : Colors.black12),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined,
                                  color: Colors.teal, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '100% Data Offline & Privat',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Data keuangan Anda disimpan secara eksklusif di dalam database lokal ponsel Anda dan tidak pernah dikirim ke server luar. Karena itu, pastikan untuk menyimpan berkas cadangan di tempat aman (seperti Google Drive pribadi Anda).',
                            style: TextStyle(
                                fontSize: 12, height: 1.4, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Branding Footer Finku
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/images/logo.png',
                          fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Finku',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Financial-ku • Manajer Keuangan v1.0.0',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C3038) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _loadingMessage,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
