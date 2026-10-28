import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'target_icons.dart';

Future<void> openGoalForm(BuildContext context, {SavingsGoal? edit}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GoalFormPage(edit: edit),
    ),
  );
}

class GoalFormPage extends StatefulWidget {
  final SavingsGoal? edit;
  const GoalFormPage({super.key, this.edit});

  @override
  State<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends State<GoalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _targetAmountCtrl = TextEditingController();
  final _initialAmountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime? _targetDate;
  bool _hasDeadline = false;
  String _selectedIcon = 'flag';
  int _selectedColor = 0xFF00897B;
  int? _selectedAssetId;
  bool _recordInitialTx = true;

  List<Asset> _assets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.edit != null) {
      final e = widget.edit!;
      _titleCtrl.text = e.title;
      _targetAmountCtrl.text = formatRibuan(e.targetAmount);
      _noteCtrl.text = e.note;
      _targetDate = e.targetDate;
      _hasDeadline = e.targetDate != null;
      _selectedIcon = e.icon;
      _selectedColor = e.color;
      _selectedAssetId = e.assetId;
    } else {
      // Default deadline 30 hari ke depan
      _targetDate = DateTime.now().add(const Duration(days: 30));
    }
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<Repo>();
    final assets = await repo.assets();
    if (!mounted) return;
    setState(() {
      _assets = assets;
      if (widget.edit == null && assets.isNotEmpty) {
        _selectedAssetId = assets.first.id;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetAmountCtrl.dispose();
    _initialAmountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2050),
      helpText: 'Pilih Batas Waktu Target',
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
        _hasDeadline = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<Repo>();
    final title = _titleCtrl.text.trim();
    final targetAmount = parseRibuan(_targetAmountCtrl.text);

    if (widget.edit == null) {
      final initialAmount = parseRibuan(_initialAmountCtrl.text);
      await repo.addSavingsGoal(
        title: title,
        targetAmount: targetAmount,
        initialAmount: initialAmount,
        targetDate: _hasDeadline ? _targetDate : null,
        color: _selectedColor,
        icon: _selectedIcon,
        assetId: _selectedAssetId,
        note: _noteCtrl.text.trim(),
        createInitialTransaction: _recordInitialTx,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Target menabung "$title" berhasil dibuat!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } else {
      await repo.updateSavingsGoal(
        widget.edit!.id,
        title: title,
        targetAmount: targetAmount,
        targetDate: _hasDeadline ? _targetDate : null,
        color: _selectedColor,
        icon: _selectedIcon,
        assetId: _selectedAssetId,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Target "$title" berhasil diperbarui'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.edit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah Target'.tr : 'Buat Target Menabung'.tr),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Pratinjau Avatar Ikon & Warna
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Color(_selectedColor).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(_selectedColor), width: 2),
                      ),
                      child: Icon(
                        getGoalIcon(_selectedIcon),
                        color: Color(_selectedColor),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nama Target
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Target *'.tr,
                      hintText: 'Misal: Beli Laptop Baru, Dana Darurat, Umrah',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.bookmark_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nama target wajib diisi';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nominal Target
                  TextFormField(
                    controller: _targetAmountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Target Nominal *'.tr,
                      hintText: '0',
                      prefixText: '${AppSettings.instance.currency.symbol} ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.savings_outlined),
                    ),
                    validator: (v) {
                      final n = parseRibuan(v ?? '');
                      if (n <= 0) return 'Nominal target harus lebih dari 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nominal Awal (Hanya untuk buat baru)
                  if (!isEdit) ...[
                    TextFormField(
                      controller: _initialAmountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Saldo Awal Tersimpan (Opsional)'.tr,
                        hintText: '0',
                        prefixText: '${AppSettings.instance.currency.symbol} ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                        helperText: 'Isi jika Anda sudah memiliki dana tabungan awal untuk target ini',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_assets.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _selectedAssetId,
                        decoration: InputDecoration(
                          labelText: 'Hubungkan Akun Rekening / Dompet',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          for (final a in _assets)
                            DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(a.name),
                            ),
                        ],
                        onChanged: (val) => setState(() => _selectedAssetId = val),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Catat di Arus Kas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Kurangi saldo aset yang dipilih untuk saldo awal', style: TextStyle(fontSize: 11)),
                        value: _recordInitialTx,
                        onChanged: (val) => setState(() => _recordInitialTx = val),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // Batas Waktu / Deadline Switch
                  Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Batas Waktu (Deadline)'.tr, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(_hasDeadline
                                ? (_targetDate != null ? tglPanjang(_targetDate!) : 'Pilih tanggal'.tr)
                                : 'Target fleksibel tanpa batas waktu'.tr),
                            value: _hasDeadline,
                            onChanged: (val) {
                              setState(() {
                                _hasDeadline = val;
                                if (val && _targetDate == null) {
                                  _targetDate = DateTime.now().add(const Duration(days: 30));
                                }
                              });
                            },
                          ),
                          if (_hasDeadline) ...[
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(_targetDate != null ? 'Ubah: ${tglPanjang(_targetDate!)}' : 'Pilih Tanggal'),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pilihan Warna
                  Text('Pilih Warna Target'.tr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kGoalColors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final color = kGoalColors[i];
                        final isSelected = color == _selectedColor;
                        return InkWell(
                          onTap: () => setState(() => _selectedColor = color),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(color).withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pilihan Ikon
                  Text('Pilih Ikon Target'.tr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in kGoalIcons)
                        InkWell(
                          onTap: () => setState(() => _selectedIcon = item.key),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedIcon == item.key
                                  ? Color(_selectedColor).withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedIcon == item.key ? Color(_selectedColor) : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 18,
                                  color: _selectedIcon == item.key ? Color(_selectedColor) : null,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _selectedIcon == item.key ? FontWeight.bold : FontWeight.normal,
                                    color: _selectedIcon == item.key ? Color(_selectedColor) : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Catatan
                  TextFormField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Catatan Tambahan (Opsional)'.tr,
                      hintText: 'Misal: Menabung 500rb per bulan dari gaji',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Tombol Simpan
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      isEdit ? 'Simpan Perubahan'.tr : 'Buat Target Sekarang'.tr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

