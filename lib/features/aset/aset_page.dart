import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'asset_detail_page.dart';

typedef _AsetData = (List<AssetGroup>, List<AssetBalance>);

/// Satu halaman dengan dua bagian: aset utama (Tunai, Bank, Kartu) di atas
/// dan grup aset tambahan buatan pengguna di bawah.
class AsetPage extends StatelessWidget {
  const AsetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aset'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Urutkan grup',
            onPressed: () => _showReorderGroups(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: RepoFuture<_AsetData>(
        load: (repo) async => (await repo.groups(), await repo.assetBalances()),
        builder: (context, data) {
          final (groups, balances) = data;
          var assets = 0;
          var debts = 0;
          for (final b in balances) {
            if (b.balance >= 0) {
              assets += b.balance;
            } else {
              debts += b.balance;
            }
          }
          final main = groups.where((g) => g.isDefault).toList();
          final extra = groups.where((g) => !g.isDefault).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _SummaryCard(assets: assets, debts: debts),
              const _SectionHeader('Aset utama'),
              for (final g in main)
                _GroupCard(
                  group: g,
                  items: balances.where((b) => b.asset.groupId == g.id).toList(),
                ),
              const Divider(height: 32),
              const _SectionHeader('Aset tambahan'),
              if (extra.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    'Belum ada grup tambahan. Ketuk Tambah untuk membuat grup aset baru, misalnya Dompet digital atau Investasi.',
                  ),
                )
              else
                for (final g in extra)
                  _GroupCard(
                    group: g,
                    items: balances.where((b) => b.asset.groupId == g.id).toList(),
                  ),
            ],
          );
        },
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    final repo = context.read<Repo>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Tambah aset'),
              subtitle: const Text('Dompet, rekening, atau kartu baru'),
              onTap: () {
                Navigator.pop(ctx);
                showAddAssetDialog(context, repo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Tambah grup aset'),
              subtitle: const Text('Kelompok baru di bagian aset tambahan'),
              onTap: () {
                Navigator.pop(ctx);
                showAddGroupDialog(context, repo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReorderGroups(BuildContext context) async {
    final repo = context.read<Repo>();
    final groups = await repo.groups();
    if (!context.mounted) return;
    if (groups.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal butuh 2 grup untuk diurutkan.')),
      );
      return;
    }

    final items = List<AssetGroup>.from(groups);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Urutkan Grup Aset'),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: ReorderableListView(
              shrinkWrap: true,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = items.removeAt(oldIndex);
                  items.insert(newIndex, item);
                });
              },
              children: [
                for (final g in items)
                  ListTile(
                    key: ValueKey(g.id),
                    dense: true,
                    leading: const Icon(Icons.drag_handle),
                    title: Text(g.name),
                    trailing: g.isDefault
                        ? const Text('Utama',
                            style: TextStyle(fontSize: 12, color: Colors.grey))
                        : null,
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
                Navigator.pop(ctx);
                await repo.reorderGroups(items.map((g) => g.id).toList());
              },
              child: const Text('Simpan Urutan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int assets;
  final int debts;

  const _SummaryCard({required this.assets, required this.debts});

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int value, Color? color) => Expanded(
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  rupiah(value),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        );
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            cell('Aset', assets, incomeColor),
            cell('Utang', debts, debts < 0 ? expenseColor : null),
            cell('Saldo bersih', assets + debts, null),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final AssetGroup group;
  final List<AssetBalance> items;

  const _GroupCard({required this.group, required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, b) => sum + b.balance);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rupiah(total),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: total < 0 ? expenseColor : null,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (val) {
                final repo = context.read<Repo>();
                if (val == 'edit') {
                  showEditGroupDialog(context, repo, group);
                } else if (val == 'delete') {
                  showDeleteGroupDialog(context, repo, group);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Ubah nama grup'),
                    ],
                  ),
                ),
                if (!group.isDefault)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Hapus grup', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        children: [
          if (items.isEmpty)
            const ListTile(dense: true, title: Text('Belum ada aset di grup ini.')),
          for (final b in items)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: Text(b.asset.name),
              trailing: Text(
                rupiah(b.balance),
                style: TextStyle(color: b.balance < 0 ? expenseColor : null),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AssetDetailPage(assetId: b.asset.id)),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  showAddAssetDialog(context, context.read<Repo>(), initialGroupId: group.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah aset'),
            ),
          ),
        ],
      ),
    );
  }
}
