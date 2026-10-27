import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

typedef _ClosingData = (Totals, List<AssetBalance>, Set<String>);

/// Tutup buku: merekap satu bulan lalu mengunci transaksinya.
class ClosingTab extends StatelessWidget {
  final DateTime month;

  const ClosingTab({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    final period = periodOf(month);
    return RepoFuture<_ClosingData>(
      keyValue: month,
      load: (repo) async => (
        await repo.totals(firstOfMonth(month), lastOfMonth(month)),
        await repo.assetBalances(upTo: lastOfMonth(month)),
        await repo.closedPeriods(),
      ),
      builder: (context, data) {
        final (totals, balances, closedPeriods) = data;
        final closed = closedPeriods.contains(period);
        final cs = Theme.of(context).colorScheme;
        final grandTotal = balances.fold<int>(0, (sum, b) => sum + b.balance);
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SummaryBar(income: totals.income, expense: totals.expense),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                closed ? Icons.lock : Icons.lock_open,
                color: closed ? cs.primary : cs.outline,
              ),
              title: Text(periodLabel(period)),
              subtitle: Text(closed
                  ? 'Sudah ditutup. Transaksi periode ini terkunci.'
                  : 'Masih terbuka. Transaksi dapat diubah.'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Saldo akhir per aset',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final b in balances)
              ListTile(
                dense: true,
                title: Text(b.asset.name),
                trailing: Text(
                  rupiah(b.balance),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: b.balance < 0 ? expenseColor : null,
                  ),
                ),
              ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Total aset',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text(
                rupiah(grandTotal),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: closed
                  ? OutlinedButton.icon(
                      onPressed: () => _reopen(context, period),
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Buka kembali periode ini'),
                    )
                  : FilledButton.icon(
                      onPressed: () => _close(context, period),
                      icon: const Icon(Icons.lock),
                      label: const Text('Tutup buku periode ini'),
                    ),
            ),
            if (closedPeriods.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Periode yang sudah ditutup',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in closedPeriods.toList()..sort((a, b) => b.compareTo(a)))
                      Chip(
                        avatar: const Icon(Icons.lock, size: 16),
                        label: Text(periodLabel(p)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _close(BuildContext context, String period) async {
    final ok = await confirm(
      context,
      title: 'Tutup buku?',
      message:
          'Transaksi pada ${periodLabel(period)} tidak dapat ditambah, diubah, atau dihapus sampai periode dibuka kembali.',
      okLabel: 'Tutup buku',
    );
    if (ok && context.mounted) await context.read<Repo>().closePeriod(period);
  }

  Future<void> _reopen(BuildContext context, String period) async {
    final ok = await confirm(
      context,
      title: 'Buka kembali?',
      message: 'Transaksi pada ${periodLabel(period)} dapat diubah lagi.',
      okLabel: 'Buka kembali',
    );
    if (ok && context.mounted) await context.read<Repo>().reopenPeriod(period);
  }
}
