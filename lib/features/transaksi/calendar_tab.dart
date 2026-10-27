import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'tx_form_page.dart';

typedef _CalendarData = (Totals, List<TxItem>, Map<String, Totals>);

class CalendarTab extends StatefulWidget {
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  const CalendarTab({super.key, required this.month, required this.onMonthChanged});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime? _selected;

  DateTime? get _effectiveSelected {
    final s = _selected;
    if (s != null && s.year == widget.month.year && s.month == widget.month.month) {
      return s;
    }
    final now = DateTime.now();
    if (now.year == widget.month.year && now.month == widget.month.month) {
      return DateTime(now.year, now.month, now.day);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return RepoFuture<_CalendarData>(
      keyValue: widget.month,
      load: (repo) async {
        final from = firstOfMonth(widget.month);
        final to = lastOfMonth(widget.month);
        return (
          await repo.totals(from, to),
          await repo.transactions(from, to),
          await repo.dailyTotals(from, to),
        );
      },
      builder: (context, data) {
        final (totals, items, daily) = data;
        final selected = _effectiveSelected;
        final dayItems = selected == null
            ? <TxItem>[]
            : items.where((t) => ymd(t.date) == ymd(selected)).toList();
        final cs = Theme.of(context).colorScheme;

        Widget cell(DateTime day, {bool today = false, bool isSelected = false}) {
          final t = daily[ymd(day)];
          final weekend = day.weekday == DateTime.sunday;
          return Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? cs.primaryContainer : null,
              border: today ? Border.all(color: cs.primary) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: weekend ? expenseColor : null,
                  ),
                ),
                if (t != null && t.income > 0)
                  Text(ringkas(t.income),
                      style: const TextStyle(color: incomeColor, fontSize: 9)),
                if (t != null && t.expense > 0)
                  Text(ringkas(t.expense),
                      style: const TextStyle(color: expenseColor, fontSize: 9)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SummaryBar(income: totals.income, expense: totals.expense),
            const Divider(height: 1),
            TableCalendar<void>(
              locale: 'id_ID',
              firstDay: DateTime.utc(2000, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: widget.month,
              headerVisible: false,
              startingDayOfWeek: StartingDayOfWeek.monday,
              rowHeight: 60,
              daysOfWeekHeight: 28,
              availableGestures: AvailableGestures.horizontalSwipe,
              calendarStyle: const CalendarStyle(outsideDaysVisible: false),
              selectedDayPredicate: (d) => selected != null && isSameDay(d, selected),
              onDaySelected: (day, _) =>
                  setState(() => _selected = DateTime(day.year, day.month, day.day)),
              onPageChanged: (focused) => widget.onMonthChanged(firstOfMonth(focused)),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, _) => cell(day),
                todayBuilder: (context, day, _) => cell(day, today: true),
                selectedBuilder: (context, day, _) => cell(
                  day,
                  today: isSameDay(day, DateTime.now()),
                  isSelected: true,
                ),
              ),
            ),
            const Divider(height: 1),
            if (selected == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Ketuk tanggal untuk melihat transaksinya.')),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '${namaHari(selected)}, ${tglPanjang(selected)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (dayItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tidak ada transaksi pada tanggal ini.'),
                )
              else
                for (final t in dayItems)
                  TxTile(item: t, onTap: () => openTxForm(context, edit: t)),
            ],
          ],
        );
      },
    );
  }
}
