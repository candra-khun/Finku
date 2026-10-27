import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class KelolaKategoriPage extends StatelessWidget {
  const KelolaKategoriPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Kategori'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Pendapatan'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CategoryListTab(type: 'expense'),
            _CategoryListTab(type: 'income'),
          ],
        ),
      ),
    );
  }
}

class _CategoryListTab extends StatefulWidget {
  final String type;

  const _CategoryListTab({required this.type});

  @override
  State<_CategoryListTab> createState() => _CategoryListTabState();
}

class _CategoryListTabState extends State<_CategoryListTab> {
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, repo),
        icon: const Icon(Icons.add),
        label: const Text('Kategori Baru'),
      ),
      body: RepoFuture<List<Category>>(
        keyValue: widget.type,
        load: (r) => r.categories(widget.type),
        builder: (context, categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('Belum ada kategori.'));
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tahan dan seret item untuk mengubah urutan kategori.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: categories.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    final list = List<Category>.from(categories);
                    final item = list.removeAt(oldIndex);
                    list.insert(newIndex, item);
                    await repo.reorderCategories(list.map((c) => c.id).toList());
                  },
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return ListTile(
                      key: ValueKey(cat.id),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(cat.color),
                      ),
                      title: Text(
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: FutureBuilder<int>(
                        future: repo.categoryUsageCount(cat.id),
                        builder: (ctx, snap) {
                          final count = snap.data ?? 0;
                          return Text(
                            count > 0 ? '$count transaksi' : 'Belum ada transaksi',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Ubah kategori',
                            onPressed: () => _showEditCategoryDialog(context, repo, cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                            tooltip: 'Hapus kategori',
                            onPressed: () => _showDeleteCategoryDialog(context, repo, cat, categories),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------- DIALOG TAMBAH KATEGORI
  Future<void> _showAddCategoryDialog(BuildContext context, Repo repo) async {
    final nameCtrl = TextEditingController();
    int selectedColor = categoryPalette.first;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Kategori ${widget.type == 'income' ? 'Pendapatan' : 'Pengeluaran'} Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nama kategori',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pilih Warna:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _colorPalettePicker(
                  selectedColor: selectedColor,
                  onSelect: (c) => setState(() => selectedColor = c),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setState(() => error = 'Nama kategori tidak boleh kosong.');
                  return;
                }
                Navigator.pop(ctx);
                final id = await repo.addCategory(name, widget.type);
                // Update warnanya jika pengguna memilih warna khusus
                await repo.updateCategory(id, name: name, color: selectedColor);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------- DIALOG UBAH KATEGORI
  Future<void> _showEditCategoryDialog(
    BuildContext context,
    Repo repo,
    Category category,
  ) async {
    final nameCtrl = TextEditingController(text: category.name);
    int selectedColor = category.color;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Ubah Kategori'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nama kategori',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pilih Warna:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _colorPalettePicker(
                  selectedColor: selectedColor,
                  onSelect: (c) => setState(() => selectedColor = c),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setState(() => error = 'Nama kategori tidak boleh kosong.');
                  return;
                }
                Navigator.pop(ctx);
                await repo.updateCategory(
                  category.id,
                  name: name,
                  color: selectedColor,
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------- DIALOG HAPUS KATEGORI
  Future<void> _showDeleteCategoryDialog(
    BuildContext context,
    Repo repo,
    Category category,
    List<Category> allCategories,
  ) async {
    final usage = await repo.categoryUsageCount(category.id);
    final otherCategories = allCategories.where((c) => c.id != category.id).toList();

    if (!context.mounted) return;

    int? targetCatId = otherCategories.isNotEmpty ? otherCategories.first.id : null;
    bool moveToAnother = otherCategories.isNotEmpty && usage > 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Hapus "${category.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (usage > 0) ...[
                Text(
                  'Kategori ini digunakan oleh $usage transaksi.',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Pindahkan transaksi'),
                      selected: moveToAnother,
                      onSelected: (_) => setState(() => moveToAnother = true),
                    ),
                    ChoiceChip(
                      label: const Text('Jadikan tanpa kategori'),
                      selected: !moveToAnother,
                      onSelected: (_) => setState(() => moveToAnother = false),
                    ),
                  ],
                ),
                if (moveToAnother) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: targetCatId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pilih kategori tujuan',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final c in otherCategories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => targetCatId = v),
                  ),
                ],
              ] else
                const Text('Kategori ini belum dipakai di transaksi manapun dan akan dihapus permanen.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(ctx);
                await repo.deleteCategory(
                  category.id,
                  targetCategoryId: moveToAnother ? targetCatId : null,
                );
              },
              child: const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorPalettePicker({
    required int selectedColor,
    required ValueChanged<int> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categoryPalette)
          GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedColor == c ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: selectedColor == c
                    ? [const BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)]
                    : null,
              ),
              child: selectedColor == c
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

