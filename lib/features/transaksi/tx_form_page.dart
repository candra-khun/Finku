import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../kategori/kelola_kategori_page.dart';

/// Membuka form tambah (edit == null), duplikat, atau ubah transaksi.
Future<void> openTxForm(
  BuildContext context, {
  TxItem? edit,
  TxItem? duplicate,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TxFormPage(edit: edit, duplicate: duplicate),
    ),
  );
}

class TxFormPage extends StatefulWidget {
  final TxItem? edit;
  final TxItem? duplicate;

  const TxFormPage({super.key, this.edit, this.duplicate});

  @override
  State<TxFormPage> createState() => _TxFormPageState();
}

class _TxFormPageState extends State<TxFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _desc = TextEditingController();

  String _type = 'expense';
  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _assetId;
  int? _toAssetId;
  final Set<int> _tagIds = {};

  // Dinaikkan setelah dialog "tambah baru" ditutup agar dropdown kembali ke
  // nilai terpilih (bukan tertinggal di opsi "+ Tambah ...").
  int _reset = 0;

  List<Category> _cats = [];
  List<Asset> _assets = [];
  List<Tag> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.edit ?? widget.duplicate;
    if (e != null) {
      _type = e.type;
      // Jika mode duplikat, gunakan tanggal hari ini agar transaksi baru tercatat sekarang
      _date = widget.duplicate != null ? DateTime.now() : e.date;
      _amount.text = formatRibuan(e.amount);
      _note.text = e.note;
      _desc.text = e.description;
      _categoryId = e.categoryId;
      _assetId = e.assetId;
      _toAssetId = e.toAssetId;
      _tagIds.addAll(e.tags.map((t) => t.id));
    }
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<Repo>();
    final cats =
        _type == 'transfer' ? <Category>[] : await repo.categories(_type);
    final assets = await repo.assets(includeArchived: widget.edit != null);
    final tags = await repo.tags();
    if (!mounted) return;
    setState(() {
      _cats = cats;
      _assets = assets;
      _tags = tags;
      _loading = false;
    });
  }

  Future<void> _changeType(String type) async {
    if (type == _type) return;
    setState(() {
      _type = type;
      _categoryId = null;
    });
    final repo = context.read<Repo>();
    final cats =
        type == 'transfer' ? <Category>[] : await repo.categories(type);
    if (!mounted) return;
    setState(() => _cats = cats);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addCategory() async {
    final repo = context.read<Repo>();
    final name = await askText(
      context,
      title: _type == 'income'
          ? 'Kategori pendapatan baru'
          : 'Kategori pengeluaran baru',
      label: 'Nama kategori',
    );
    if (name == null) return;
    final id = await repo.addCategory(name, _type);
    final cats = await repo.categories(_type);
    if (!mounted) return;
    setState(() {
      _cats = cats;
      _categoryId = id;
    });
  }

  /// [target]: 'from' atau 'to' (aset tujuan pada transfer).
  Future<void> _addAsset(String target) async {
    final repo = context.read<Repo>();
    final id = await showAddAssetDialog(context, repo);
    if (id == null) return;
    final assets = await repo.assets(includeArchived: widget.edit != null);
    if (!mounted) return;
    setState(() {
      _assets = assets;
      if (target == 'to') {
        _toAssetId = id;
      } else {
        _assetId = id;
      }
    });
  }

  Future<void> _addTag() async {
    final repo = context.read<Repo>();
    final name = await askText(context, title: 'Tag baru', label: 'Nama tag');
    if (name == null) return;
    final id = await repo.addTag(name);
    final tags = await repo.tags();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _tagIds.add(id);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<Repo>();
    final isTransfer = _type == 'transfer';
    final input = TxInput(
      type: _type,
      date: _date,
      amount: parseRibuan(_amount.text),
      categoryId: isTransfer ? null : _categoryId,
      assetId: _assetId!,
      toAssetId: isTransfer ? _toAssetId : null,
      note: _note.text.trim(),
      description: _desc.text.trim(),
      tagIds: _tagIds.toList(),
    );
    try {
      if (widget.edit == null) {
        await repo.addTransaction(input);
      } else {
        await repo.updateTransaction(widget.edit!.id, input);
      }
      if (mounted) Navigator.pop(context);
    } on ClosedPeriodException catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Hapus transaksi?',
      message: 'Transaksi ini akan dihapus dan saldo aset disesuaikan.',
      okLabel: 'Hapus',
    );
    if (!ok) return;
    final repo = context.read<Repo>();
    try {
      await repo.deleteTransaction(widget.edit!.id);
      if (mounted) Navigator.pop(context);
    } on ClosedPeriodException catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.edit != null;
    final isTransfer = _type == 'transfer';
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah transaksi' : 'Tambah transaksi'),
        actions: [
          if (isEdit) ...[
            IconButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => TxFormPage(duplicate: widget.edit),
                  ),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Duplikat transaksi',
            ),
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'income', label: Text('Pendapatan')),
                      ButtonSegment(
                          value: 'expense', label: Text('Pengeluaran')),
                      ButtonSegment(value: 'transfer', label: Text('Transfer')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => _changeType(s.first),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text('${namaHari(_date)}, ${tglPanjang(_date)}'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Total',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = parseRibuan(v ?? '');
                      if (n <= 0) return 'Isi total lebih dari 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!isTransfer) ...[
                    DropdownButtonFormField<int>(
                      key: ValueKey('cat-$_type-$_reset'),
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Kategori', border: OutlineInputBorder()),
                      items: [
                        for (final c in _cats)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                        const DropdownMenuItem(
                            value: -1, child: Text('+ Tambah kategori baru')),
                        const DropdownMenuItem(
                            value: -2, child: Text('⚙ Kelola kategori...')),
                      ],
                      onChanged: (v) {
                        if (v == -1) {
                          _addCategory().whenComplete(() {
                            if (mounted) setState(() => _reset++);
                          });
                        } else if (v == -2) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const KelolaKategoriPage()),
                          ).then((_) async {
                            if (mounted) {
                              final repo = context.read<Repo>();
                              final cats = await repo.categories(_type);
                              setState(() {
                                _cats = cats;
                                if (!_cats.any((c) => c.id == _categoryId)) {
                                  _categoryId =
                                      _cats.isNotEmpty ? _cats.first.id : null;
                                }
                                _reset++;
                              });
                            }
                          });
                        } else {
                          setState(() => _categoryId = v);
                        }
                      },
                      validator: (v) => v == null ? 'Pilih kategori' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _assetDropdown(
                    label: isTransfer ? 'Dari aset' : 'Aset',
                    value: _assetId,
                    target: 'from',
                    onSelected: (v) => setState(() => _assetId = v),
                  ),
                  if (isTransfer) ...[
                    const SizedBox(height: 16),
                    _assetDropdown(
                      label: 'Ke aset',
                      value: _toAssetId,
                      target: 'to',
                      onSelected: (v) => setState(() => _toAssetId = v),
                      validator: (v) {
                        if (v == null) return 'Pilih aset';
                        if (v == _assetId) return 'Aset tujuan harus berbeda';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Catatan', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Text('Tag', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final t in _tags)
                        FilterChip(
                          label: Text(t.name),
                          selected: _tagIds.contains(t.id),
                          onSelected: (on) => setState(() {
                            if (on) {
                              _tagIds.add(t.id);
                            } else {
                              _tagIds.remove(t.id);
                            }
                          }),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah tag'),
                        onPressed: _addTag,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _desc,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: Text(isEdit ? 'Simpan perubahan' : 'Simpan'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _assetDropdown({
    required String label,
    required int? value,
    required String target,
    required ValueChanged<int?> onSelected,
    String? Function(int?)? validator,
  }) {
    return DropdownButtonFormField<int>(
      key: ValueKey('asset-$target-$_reset'),
      initialValue: value,
      isExpanded: true,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final a in _assets)
          DropdownMenuItem(value: a.id, child: Text(a.name)),
        const DropdownMenuItem(value: -1, child: Text('+ Tambah aset baru')),
      ],
      onChanged: (v) {
        if (v == -1) {
          _addAsset(target).whenComplete(() {
            if (mounted) setState(() => _reset++);
          });
        } else {
          onSelected(v);
        }
      },
      validator: validator ?? (v) => v == null ? 'Pilih aset' : null,
    );
  }
}
