import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class TagihanFormPage extends StatefulWidget {
  final RecurringTx? initial;

  const TagihanFormPage({super.key, this.initial});

  @override
  State<TagihanFormPage> createState() => _TagihanFormPageState();
}

class _TagihanFormPageState extends State<TagihanFormPage> {
  final _formKey = GlobalKey<FormState>();

  late String _type;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  int? _categoryId;
  int? _assetId;
  int? _toAssetId;

  String _frequency = 'monthly';
  int _interval = 1;
  late DateTime _startDate;
  late DateTime _nextDueDate;
  bool _autoRecord = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _type = init?.type ?? 'expense';
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _amountCtrl = TextEditingController(
      text: init != null && init.amount > 0 ? formatRibuan(init.amount) : '',
    );
    _noteCtrl = TextEditingController(text: init?.note ?? '');

    _categoryId = init?.categoryId;
    _assetId = init?.assetId;
    _toAssetId = init?.toAssetId;

    _frequency = init?.frequency ?? 'monthly';
    _interval = init?.interval ?? 1;
    _startDate = init?.startDate ?? DateTime.now();
    _nextDueDate = init?.nextDueDate ?? DateTime.now();
    _autoRecord = init?.autoRecord ?? false;
    _isActive = init?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final current = isStartDate ? _startDate : _nextDueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_nextDueDate.isBefore(_startDate)) {
            _nextDueDate = _startDate;
          }
        } else {
          _nextDueDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = parseRibuan(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari 0'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (_assetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih rekening / aset pembayaran'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (_type == 'transfer' && _toAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih aset tujuan transfer'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final repo = context.read<Repo>();
    final title = _titleCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final dueDay = _nextDueDate.day;

    if (widget.initial == null) {
      await repo.insertRecurring(
        title: title,
        type: _type,
        amount: amount,
        categoryId: _type == 'transfer' ? null : _categoryId,
        assetId: _assetId!,
        toAssetId: _type == 'transfer' ? _toAssetId : null,
        frequency: _frequency,
        interval: _interval,
        dueDay: dueDay,
        startDate: _startDate,
        nextDueDate: _nextDueDate,
        autoRecord: _autoRecord,
        isActive: _isActive,
        note: note,
      );
    } else {
      await repo.updateRecurring(
        id: widget.initial!.id,
        title: title,
        type: _type,
        amount: amount,
        categoryId: _type == 'transfer' ? null : _categoryId,
        assetId: _assetId!,
        toAssetId: _type == 'transfer' ? _toAssetId : null,
        frequency: _frequency,
        interval: _interval,
        dueDay: dueDay,
        startDate: _startDate,
        nextDueDate: _nextDueDate,
        autoRecord: _autoRecord,
        isActive: _isActive,
        note: note,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initial == null ? 'Transaksi berulang berhasil ditambahkan' : 'Perubahan berhasil disimpan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Tambah Transaksi Berulang' : 'Edit Transaksi Berulang'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Segmented Tipe Transaksi
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Pengeluaran')),
                ButtonSegment(value: 'income', label: Text('Pemasukan')),
                ButtonSegment(value: 'transfer', label: Text('Transfer')),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (set) {
                setState(() {
                  _type = set.first;
                  _categoryId = null;
                });
              },
            ),

            const SizedBox(height: 20),

            // Nama / Judul Tagihan
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Tagihan / Rutinitas *',
                hintText: 'Contoh: WiFi Rumah, Kos Bulanan, Spotify',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama harus diisi' : null,
            ),

            const SizedBox(height: 16),

            // Nominal
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsSeparatorInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Nominal *',
                hintText: '0',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nominal harus diisi';
                if (parseRibuan(v) <= 0) return 'Nominal harus lebih dari 0';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Kategori (jika expense / income)
            if (_type != 'transfer') ...[
              FutureBuilder<List<Category>>(
                future: repo.categories(_type),
                builder: (context, snap) {
                  final cats = snap.data ?? [];
                  if (_categoryId == null && cats.isNotEmpty) {
                    _categoryId = cats.first.id;
                  }
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                      isDense: true,
                    ),
                    initialValue: cats.any((c) => c.id == _categoryId) ? _categoryId : null,
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(c.color),
                              ),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (val) => setState(() => _categoryId = val),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Aset / Rekening Sumber
            FutureBuilder<List<Asset>>(
              future: repo.assets(),
              builder: (context, snap) {
                final assets = (snap.data ?? []).where((a) => !a.archived).toList();
                if (_assetId == null && assets.isNotEmpty) {
                  _assetId = assets.first.id;
                }
                return DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: _type == 'transfer' ? 'Dari Aset (Sumber)' : 'Aset / Rekening Pembayaran *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    isDense: true,
                  ),
                  initialValue: assets.any((a) => a.id == _assetId) ? _assetId : null,
                  items: [
                    for (final a in assets)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ),
                  ],
                  onChanged: (val) => setState(() => _assetId = val),
                );
              },
            ),

            const SizedBox(height: 16),

            // Aset Tujuan (jika Transfer)
            if (_type == 'transfer') ...[
              FutureBuilder<List<Asset>>(
                future: repo.assets(),
                builder: (context, snap) {
                  final assets = (snap.data ?? []).where((a) => !a.archived && a.id != _assetId).toList();
                  if (_toAssetId == null && assets.isNotEmpty) {
                    _toAssetId = assets.first.id;
                  }
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Ke Aset (Tujuan) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.move_to_inbox_outlined),
                      isDense: true,
                    ),
                    initialValue: assets.any((a) => a.id == _toAssetId) ? _toAssetId : null,
                    items: [
                      for (final a in assets)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ),
                    ],
                    onChanged: (val) => setState(() => _toAssetId = val),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // -------------------------------- JADWAL & FREKUENSI
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengaturan Frekuensi & Jadwal',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),

                    // Pilihan Frekuensi
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Frekuensi Pengulangan',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      initialValue: _frequency,
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Bulanan (Setiap Bulan)')),
                        DropdownMenuItem(value: 'weekly', child: Text('Mingguan (Setiap Minggu)')),
                        DropdownMenuItem(value: 'daily', child: Text('Harian (Setiap Hari)')),
                        DropdownMenuItem(value: 'yearly', child: Text('Tahunan (Setiap Tahun)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _frequency = val);
                      },
                    ),

                    const SizedBox(height: 14),

                    // Tanggal Jatuh Tempo Berikutnya
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Icon(Icons.event, color: theme.colorScheme.primary, size: 20),
                      ),
                      title: const Text('Jatuh Tempo Berikutnya', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        tglPanjang(_nextDueDate),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => _pickDate(isStartDate: false),
                        child: const Text('Ubah Tanggal'),
                      ),
                    ),

                    const Divider(height: 24),

                    // Opsi Catat Otomatis
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        _autoRecord ? Icons.autorenew : Icons.notifications_active_outlined,
                        color: _autoRecord ? Colors.teal : Colors.grey,
                      ),
                      title: const Text('Catat Otomatis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        _autoRecord
                            ? 'Aplikasi otomatis mencatat transaksi saat tanggal jatuh tempo tiba'
                            : 'Aplikasi menampilkan pengingat untuk Anda konfirmasi/bayar manual',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _autoRecord,
                      onChanged: (val) => setState(() => _autoRecord = val),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Catatan
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (Opsional)',
                hintText: 'Misal: No. Pelanggan 123456 / Bayar sebelum tgl 20',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),

            const SizedBox(height: 24),

            // Tombol Simpan
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.initial == null ? 'Simpan Transaksi Berulang' : 'Perbarui Transaksi Berulang',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

