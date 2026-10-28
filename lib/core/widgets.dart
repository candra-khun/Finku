import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'format.dart';
import 'localization.dart';

/// Memuat data dari Repo dan memuat ulang otomatis setiap kali data berubah
/// atau [keyValue] berganti. Data lama tetap tampil selama memuat ulang,
/// sehingga layar tidak berkedip.
class RepoFuture<T> extends StatefulWidget {
  final Future<T> Function(Repo repo) load;
  final Widget Function(BuildContext context, T data) builder;
  final Object? keyValue;

  const RepoFuture({
    super.key,
    required this.load,
    required this.builder,
    this.keyValue,
  });

  @override
  State<RepoFuture<T>> createState() => _RepoFutureState<T>();
}

class _RepoFutureState<T> extends State<RepoFuture<T>> {
  late final Repo _repo;
  T? _data;
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repo = context.read<Repo>();
    _repo.addListener(_reload);
    _reload();
  }

  @override
  void didUpdateWidget(covariant RepoFuture<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyValue != widget.keyValue) _reload();
  }

  @override
  void dispose() {
    _repo.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final result = await widget.load(_repo);
      if (!mounted) return;
      setState(() {
        _data = result;
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      debugPrint('RepoFuture error: $e');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && !_loaded) {
      return Center(child: Text('Gagal memuat data: $_error'));
    }
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return widget.builder(context, _data as T);
  }
}

/// Ringkasan Pendapatan, Pengeluaran, dan Total.
class SummaryBar extends StatelessWidget {
  final int income;
  final int expense;

  const SummaryBar({super.key, required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final total = income - expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          _cell(context, 'Pendapatan'.tr, rupiah(income), incomeColor),
          _cell(context, 'Pengeluaran'.tr, rupiah(expense), expenseColor),
          _cell(context, 'Total'.tr, rupiah(total),
              total < 0 ? expenseColor : Theme.of(context).colorScheme.onSurface),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigasi periode dengan panah kiri/kanan.
class PeriodNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onTapLabel;

  const PeriodNavigator({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.onTapLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        InkWell(
          onTap: onTapLabel,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;

  const EmptyState({super.key, required this.text, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

class TxTile extends StatelessWidget {
  final TxItem item;
  final VoidCallback? onTap;

  const TxTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTransfer = item.type == 'transfer';
    final color = switch (item.type) {
      'income' => incomeColor,
      'expense' => expenseColor,
      _ => transferColor,
    };
    final sign = switch (item.type) {
      'income' => '+',
      'expense' => '-',
      _ => '',
    };
    final parts = <String>[
      if (item.note.isNotEmpty) item.note,
      isTransfer ? '${item.assetName} → ${item.toAssetName ?? '-'}' : item.assetName,
      if (item.tags.isNotEmpty) item.tags.map((t) => '#${t.name}').join(' '),
    ];
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          switch (item.type) {
            'income' => Icons.south_west,
            'expense' => Icons.north_east,
            _ => Icons.swap_horiz,
          },
          size: 16,
          color: color,
        ),
      ),
      title: Text(isTransfer ? 'Transfer' : (item.categoryName ?? '-')),
      subtitle: Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '$sign${rupiah(item.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Transaksi dikelompokkan per tanggal, lengkap dengan subtotal harian.
List<Widget> groupedTxWidgets(
  BuildContext context,
  List<TxItem> items,
  void Function(TxItem item)? onTap,
) {
  final widgets = <Widget>[];
  final byDate = <String, List<TxItem>>{};
  for (final t in items) {
    byDate.putIfAbsent(ymd(t.date), () => []).add(t);
  }
  final headerColor = Theme.of(context).colorScheme.surfaceContainerHighest;
  for (final entry in byDate.entries) {
    final d = parseYmd(entry.key);
    var inc = 0;
    var exp = 0;
    for (final t in entry.value) {
      if (t.type == 'income') inc += t.amount;
      if (t.type == 'expense') exp += t.amount;
    }
    widgets.add(Container(
      color: headerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${d.day} ${bulanPendek[d.month - 1]} · ${namaHari(d)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (inc > 0)
            Text(rupiah(inc), style: const TextStyle(color: incomeColor, fontSize: 12)),
          if (inc > 0 && exp > 0) const SizedBox(width: 12),
          if (exp > 0)
            Text(rupiah(exp), style: const TextStyle(color: expenseColor, fontSize: 12)),
        ],
      ),
    ));
    for (final t in entry.value) {
      widgets.add(TxTile(item: t, onTap: onTap == null ? null : () => onTap(t)));
    }
  }
  return widgets;
}
