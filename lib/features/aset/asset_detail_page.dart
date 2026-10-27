import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../transaksi/tx_form_page.dart';

typedef _DetailData = (AssetBalance?, List<TxItem>);

class AssetDetailPage extends StatelessWidget {
  final int assetId;

  const AssetDetailPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context) {
    // Material di luar agar tampilan "memuat" punya latar yang benar.
    return Material(child: RepoFuture<_DetailData>(
      load: (repo) async {
        final balances = await repo.assetBalances();
        AssetBalance? found;
        for (final b in balances) {
          if (b.asset.id == assetId) found = b;
        }
        final items = await repo.transactions(
          DateTime(2000),
          DateTime(2100, 12, 31),
          assetId: assetId,
        );
        return (found, items);
      },
      builder: (context, data) {
        final (balance, items) = data;
        return Scaffold(
          appBar: AppBar(
            title: Text(balance?.asset.name ?? 'Aset'),
            actions: [
              if (balance != null) ...[
                IconButton(
                  tooltip: 'Ubah aset',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      showEditAssetDialog(context, context.read<Repo>(), balance.asset),
                ),
                IconButton(
                  tooltip: 'Hapus atau arsipkan',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(context, balance.asset),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              if (balance != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Saldo', style: Theme.of(context).textTheme.labelMedium),
                      Text(
                        rupiah(balance.balance),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: balance.balance < 0 ? expenseColor : null,
                            ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(text: 'Belum ada transaksi pada aset ini.')
                    : ListView(
                        children: groupedTxWidgets(
                          context,
                          items,
                          (t) => openTxForm(context, edit: t),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    ));
  }

  Future<void> _remove(BuildContext context, Asset asset) async {
    final repo = context.read<Repo>();
    final ok = await confirm(
      context,
      title: 'Hapus aset?',
      message:
          'Jika ${asset.name} sudah punya transaksi, aset hanya diarsipkan: tidak muncul lagi di pilihan dan daftar aset, tetapi riwayat transaksi tetap utuh.',
      okLabel: 'Lanjutkan',
    );
    if (!ok) return;
    await repo.removeAsset(asset.id);
    if (context.mounted) Navigator.pop(context);
  }
}
