import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../anggaran/anggaran_page.dart';
import '../tagihan/tagihan_page.dart';
import 'calendar_tab.dart';
import 'closing_tab.dart';
import 'memo_tab.dart';
import 'tx_form_page.dart';
import 'tx_search_delegate.dart';

class TransaksiPage extends StatefulWidget {
  const TransaksiPage({super.key});

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['Harian', 'Kalender', 'Bulanan', 'Tutup Buku', 'Memo'];

  late final TabController _tab;
  DateTime _month = firstOfMonth(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  void _shiftYear(int delta) =>
      setState(() => _month = DateTime(_month.year + delta, _month.month, 1));

  Widget _monthNav() => PeriodNavigator(
        label: '${bulan[_month.month - 1]} ${_month.year}',
        onPrev: () => _shiftMonth(-1),
        onNext: () => _shiftMonth(1),
      );

  Widget _dueBillBanner(BuildContext context) {
    final repo = context.watch<Repo>();
    return FutureBuilder<List<RecurringTx>>(
      future: repo.getDueOrUpcomingReminders(),
      builder: (context, snap) {
        final dues = snap.data?.where((i) => i.isOverdue || i.isDueToday).toList() ?? [];
        if (dues.isEmpty) return const SizedBox.shrink();

        final first = dues.first;
        final text = dues.length == 1
            ? 'Pengingat: Tagihan "${first.title}" ${first.isDueToday ? "jatuh tempo hari ini!" : "lewat jatuh tempo!"}'
            : 'Pengingat: ${dues.length} tagihan jatuh tempo / terlewat!';

        return Material(
          color: Colors.amber.shade900.withValues(alpha: 0.12),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TagihanPage()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orangeAccent),
                    ),
                  ),
                  const Text(
                    'Lihat',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.orangeAccent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _fab() {
    switch (_tab.index) {
      case 0:
      case 1:
      case 2:
        return FloatingActionButton(
          onPressed: () => openTxForm(context),
          tooltip: 'Tambah transaksi',
          child: const Icon(Icons.add),
        );
      case 4:
        return FloatingActionButton(
          onPressed: () => showMemoDialog(context),
          tooltip: 'Tambah memo',
          child: const Icon(Icons.edit_note),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          FutureBuilder<List<RecurringTx>>(
            future: context.watch<Repo>().getDueOrUpcomingReminders(),
            builder: (context, snap) {
              final dueCount = snap.data?.where((i) => i.isOverdue || i.isDueToday).length ?? 0;
              return IconButton(
                tooltip: 'Transaksi Berulang & Tagihan',
                icon: Badge(
                  isLabelVisible: dueCount > 0,
                  label: Text('$dueCount'),
                  child: const Icon(Icons.event_repeat_outlined),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TagihanPage()),
                  );
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Anggaran',
            icon: const Icon(Icons.track_changes_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnggaranPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Cari transaksi',
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: TxSearchDelegate(context.read<Repo>()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),
      floatingActionButton: _fab(),
      // Geser antar tab dimatikan agar tidak bentrok dengan geser kalender.
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Column(children: [
            _dueBillBanner(context),
            _monthNav(),
            Expanded(child: HarianTab(month: _month)),
          ]),
          Column(children: [
            _monthNav(),
            Expanded(
              child: CalendarTab(
                month: _month,
                onMonthChanged: (m) => setState(() => _month = m),
              ),
            ),
          ]),
          Column(children: [
            PeriodNavigator(
              label: '${_month.year}',
              onPrev: () => _shiftYear(-1),
              onNext: () => _shiftYear(1),
            ),
            Expanded(
              child: BulananTab(
                year: _month.year,
                onPickMonth: (m) {
                  setState(() => _month = m);
                  _tab.animateTo(0);
                },
              ),
            ),
          ]),
          Column(children: [
            _monthNav(),
            Expanded(child: ClosingTab(month: _month)),
          ]),
          const MemoTab(),
        ],
      ),
    );
  }
}

class HarianTab extends StatelessWidget {
  final DateTime month;

  const HarianTab({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    return RepoFuture<(Totals, List<TxItem>)>(
      keyValue: month,
      load: (repo) async {
        final from = firstOfMonth(month);
        final to = lastOfMonth(month);
        return (await repo.totals(from, to), await repo.transactions(from, to));
      },
      builder: (context, data) {
        final (totals, items) = data;
        return Column(
          children: [
            SummaryBar(income: totals.income, expense: totals.expense),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(text: 'Belum ada transaksi bulan ini.\nKetuk + untuk menambah.')
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: groupedTxWidgets(
                        context,
                        items,
                        (t) => openTxForm(context, edit: t),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class BulananTab extends StatelessWidget {
  final int year;
  final ValueChanged<DateTime> onPickMonth;

  const BulananTab({super.key, required this.year, required this.onPickMonth});

  @override
  Widget build(BuildContext context) {
    return RepoFuture<Map<int, Totals>>(
      keyValue: year,
      load: (repo) => repo.monthlyTotals(year),
      builder: (context, map) {
        var inc = 0;
        var exp = 0;
        for (final t in map.values) {
          inc += t.income;
          exp += t.expense;
        }
        final muted = Theme.of(context).colorScheme.outline;
        return Column(
          children: [
            SummaryBar(income: inc, expense: exp),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: 12,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = i + 1;
                  final t = map[m] ?? Totals.zero;
                  final empty = map[m] == null;
                  return ListTile(
                    onTap: () => onPickMonth(DateTime(year, m, 1)),
                    title: Text(
                      bulan[i],
                      style: TextStyle(color: empty ? muted : null),
                    ),
                    subtitle: empty ? null : Text('Total ${rupiah(t.total)}'),
                    trailing: empty
                        ? Text('-', style: TextStyle(color: muted))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(rupiah(t.income),
                                  style: const TextStyle(color: incomeColor, fontSize: 13)),
                              Text(rupiah(t.expense),
                                  style: const TextStyle(color: expenseColor, fontSize: 13)),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
