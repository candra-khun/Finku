import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/dialogs.dart';

class MasterMataUangPage extends StatefulWidget {
  const MasterMataUangPage({super.key});

  @override
  State<MasterMataUangPage> createState() => _MasterMataUangPageState();
}

class _MasterMataUangPageState extends State<MasterMataUangPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddCustomCurrencyDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    bool isPrefix = true;
    String thousandSep = '.';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final decimalSep = thousandSep == '.' ? ',' : '.';
            final previewVal = isPrefix
                ? '${symbolCtrl.text.isEmpty ? "Rp" : symbolCtrl.text} 1${thousandSep}500${thousandSep}000'
                : '1${thousandSep}500${thousandSep}000 ${symbolCtrl.text.isEmpty ? "Rp" : symbolCtrl.text}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.teal),
                  SizedBox(width: 10),
                  Text('Tambah Mata Uang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pratinjau Langsung
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pratinjau Format:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            previewVal,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kode Mata Uang
                    TextFormField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Kode Mata Uang *',
                        hintText: 'Misal: KRW, THB, BTC',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Nama Mata Uang
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Mata Uang *',
                        hintText: 'Misal: Won Korea, Baht Thailand',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Simbol
                    TextFormField(
                      controller: symbolCtrl,
                      decoration: InputDecoration(
                        labelText: 'Simbol Mata Uang *',
                        hintText: 'Misal: ₩, ฿, kr, CHF',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Posisi Simbol
                    const Text('Posisi Simbol:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Di Depan (Rp 1.000)', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: false, label: Text('Di Belakang (1.000 Rp)', style: TextStyle(fontSize: 11))),
                        ],
                        selected: {isPrefix},
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                        onSelectionChanged: (set) => setDialogState(() => isPrefix = set.first),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pemisah Ribuan
                    const Text('Pemisah Ribuan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: '.', label: Text('Titik (1.000.000)', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: ',', label: Text('Koma (1,000,000)', style: TextStyle(fontSize: 11))),
                        ],
                        selected: {thousandSep},
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                        onSelectionChanged: (set) => setDialogState(() => thousandSep = set.first),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final code = codeCtrl.text.trim().toUpperCase();
                    final name = nameCtrl.text.trim();
                    final symbol = symbolCtrl.text.trim();

                    if (code.isEmpty || name.isEmpty || symbol.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Semua field wajib diisi')),
                      );
                      return;
                    }

                    final newCurrency = CurrencyModel(
                      code: code,
                      name: name,
                      symbol: symbol,
                      isPrefix: isPrefix,
                      thousandSep: thousandSep,
                      decimalSep: decimalSep,
                      flag: '🪙',
                      isCustom: true,
                    );

                    await AppSettings.instance.addCustomCurrency(newCurrency);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Mata uang $name ($code) berhasil ditambahkan & diaktifkan'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan & Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Mata Uang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Mata Uang Kustom',
            onPressed: () => _showAddCustomCurrencyDialog(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final current = settings.currency;
          final allCurrencies = settings.allCurrencies;

          final filteredCurrencies = allCurrencies.where((c) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(query) ||
                c.code.toLowerCase().contains(query) ||
                c.symbol.toLowerCase().contains(query);
          }).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Kartu Pratinjau Mata Uang Aktif
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E2826) : const Color(0xFFE6F4EA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.teal.withValues(alpha: 0.2),
                                child: Text(current.flag, style: const TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    current.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    '${current.code} • Simbol "${current.symbol}"',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Aktif',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Format Contoh Live
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pemasukan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                settings.formatMoney(2500000),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Pengeluaran', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                settings.formatMoney(-750000),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Ringkas', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                settings.formatCompact(1500000),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pemisah Ribuan: "${current.thousandSep}" • Posisi: ${current.isPrefix ? "Di Depan" : "Di Belakang"}',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Kolom Pencarian Mata Uang
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari mata uang (nama, kode, atau simbol)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DAFTAR MATA UANG (${filteredCurrencies.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddCustomCurrencyDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Kustom', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 3. Daftar Mata Uang
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredCurrencies.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 64,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  itemBuilder: (ctx, i) {
                    final item = filteredCurrencies[i];
                    final isSelected = item.code == current.code;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.teal.withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                        child: Text(item.flag, style: const TextStyle(fontSize: 20)),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.teal : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isCustom)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Kustom',
                                style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${item.code} • Simbol: "${item.symbol}" • Contoh: ${item.isPrefix ? "${item.symbol} 1${item.thousandSep}000" : "1${item.thousandSep}000 ${item.symbol}"}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.isCustom)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              tooltip: 'Hapus Mata Uang Kustom',
                              onPressed: () async {
                                final ok = await confirm(
                                  context,
                                  title: 'Hapus Mata Uang?',
                                  message: 'Mata uang ${item.name} (${item.code}) akan dihapus.',
                                  okLabel: 'Hapus',
                                );
                                if (ok) {
                                  await settings.deleteCustomCurrency(item.code);
                                }
                              },
                            ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: Colors.teal)
                          else
                            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                        ],
                      ),
                      onTap: () async {
                        await settings.setCurrency(item);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Mata uang aktif diubah ke ${item.name} (${item.symbol})'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.teal,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

