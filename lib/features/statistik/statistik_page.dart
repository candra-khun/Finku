import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

enum StatMode { month, week, year, range }

class StatPeriod {
  final DateTime from;
  final DateTime to;
  final String label;

  const StatPeriod(this.from, this.to, this.label);

  @override
  bool operator ==(Object other) =>
      other is StatPeriod && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class _StatData {
  final Totals totals;
  final List<CategoryStat> stats;

  const _StatData(this.totals, this.stats);
}

/// Palet warna cerah berurutan sesuai diagram pada screenshot
const List<Color> _chartPalette = [
  Color(0xFFFF5C5C), // Coral Red (Pakaian)
  Color(0xFFFF914D), // Coral Orange (Kebutuhan Orang Tua)
  Color(0xFFFFBD59), // Amber (Transportasi)
  Color(0xFFFFDF00), // Yellow (MEMINJAMKAN)
  Color(0xFFD4E157), // Lime (Sceen Care)
  Color(0xFF7CB342), // Green (Motor)
  Color(0xFF00E5FF), // Teal (kuota)
  Color(0xFF29B6F6), // Sky Blue (GYM)
  Color(0xFFAB47BC), // Purple
  Color(0xFFEC407A), // Pink
  Color(0xFF26A69A), // Mint
  Color(0xFFFFA726), // Light Orange
];

class StatistikPage extends StatefulWidget {
  const StatistikPage({super.key});

  @override
  State<StatistikPage> createState() => _StatistikPageState();
}

class _StatistikPageState extends State<StatistikPage> {
  StatMode _mode = StatMode.month;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _range;
  String _selectedType = 'expense'; // Default Pengeluaran seperti pada gambar

  static const _modeLabels = {
    StatMode.month: 'Bulanan',
    StatMode.week: 'Mingguan',
    StatMode.year: 'Tahunan',
    StatMode.range: 'Periode',
  };

  StatPeriod get _period {
    final a = _anchor;
    switch (_mode) {
      case StatMode.month:
        return StatPeriod(
          DateTime(a.year, a.month, 1),
          DateTime(a.year, a.month + 1, 0),
          '${bulanPendek[a.month - 1]} ${a.year}',
        );
      case StatMode.week:
        final start = DateTime(a.year, a.month, a.day - (a.weekday - 1));
        final end = DateTime(start.year, start.month, start.day + 6);
        return StatPeriod(
          start,
          end,
          '${start.day} ${bulanPendek[start.month - 1]} - ${end.day} ${bulanPendek[end.month - 1]} ${end.year}',
        );
      case StatMode.year:
        return StatPeriod(
          DateTime(a.year, 1, 1),
          DateTime(a.year, 12, 31),
          '${a.year}',
        );
      case StatMode.range:
        final r = _range ??
            DateTimeRange(
              start: DateTime(a.year, a.month, 1),
              end: DateTime(a.year, a.month + 1, 0),
            );
        return StatPeriod(
          r.start,
          r.end,
          '${tglPendek(r.start)} - ${tglPendek(r.end)}',
        );
    }
  }

  void _shift(int dir) {
    final a = _anchor;
    setState(() {
      switch (_mode) {
        case StatMode.month:
          _anchor = DateTime(a.year, a.month + dir, 1);
        case StatMode.week:
          _anchor = DateTime(a.year, a.month, a.day + 7 * dir);
        case StatMode.year:
          _anchor = DateTime(a.year + dir, 1, 1);
        case StatMode.range:
          final r = _period;
          final span = r.to.difference(r.from).inDays + 1;
          _range = DateTimeRange(
            start: DateTime(r.from.year, r.from.month, r.from.day + span * dir),
            end: DateTime(r.to.year, r.to.month, r.to.day + span * dir),
          );
      }
    });
  }

  Future<void> _pickRange() async {
    final current = _period;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: current.from, end: current.to),
    );
    if (picked != null) {
      setState(() {
        _mode = StatMode.range;
        _range = picked;
      });
    }
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _anchor = DateTime(picked.year, picked.month, 1));
    }
  }

  void _selectMode(StatMode mode) {
    if (mode == StatMode.range) {
      _pickRange();
    } else {
      setState(() => _mode = mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _period;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: SafeArea(
        child: RepoFuture<_StatData>(
          keyValue: (_selectedType, period),
          load: (repo) async {
            final totals = await repo.totals(period.from, period.to);
            final stats =
                await repo.categoryStats(_selectedType, period.from, period.to);
            return _StatData(totals, stats);
          },
          builder: (context, data) {
            final totals = data.totals;
            final stats = data.stats;
            final totalAmount = stats.fold<int>(0, (sum, s) => sum + s.total);

            return Column(
              children: [
                // 1. Baris Navigasi Atas: < Okt 2026 >    Bulanan v
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Pemilih Tanggal / Periode
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _shift(-1),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.chevron_left, size: 24),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _mode == StatMode.range
                                ? _pickRange
                                : () => _pickMonth(context),
                            child: Text(
                              period.label,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _shift(1),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.chevron_right, size: 24),
                            ),
                          ),
                        ],
                      ),
                      // Dropdown Mode (Bulanan / Mingguan / Tahunan / Periode)
                      PopupMenuButton<StatMode>(
                        initialValue: _mode,
                        onSelected: _selectMode,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) => [
                          for (final m in StatMode.values)
                            PopupMenuItem(
                              value: m,
                              child: Text(_modeLabels[m]!),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _modeLabels[_mode]!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Tab Bar: Pendapatan Rp ...    Pengeluaran Rp ...
                Row(
                  children: [
                    _tabButton(
                      label: 'Pendapatan',
                      amount: '${rupiah(totals.income)},00',
                      isSelected: _selectedType == 'income',
                      onTap: () => setState(() => _selectedType = 'income'),
                    ),
                    _tabButton(
                      label: 'Pengeluaran',
                      amount: '${rupiah(totals.expense)},00',
                      isSelected: _selectedType == 'expense',
                      onTap: () => setState(() => _selectedType = 'expense'),
                    ),
                  ],
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),

                // 3. Konten: Diagram Pie Solid & List Kategori
                Expanded(
                  child: stats.isEmpty || totalAmount == 0
                      ? Center(
                          child: Text(
                            _selectedType == 'income'
                                ? 'Belum ada pendapatan pada periode ini.'
                                : 'Belum ada pengeluaran pada periode ini.',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            const SizedBox(height: 16),
                            // Diagram Lingkaran Solid dengan Callout Lines
                            _PieChartWithCallouts(
                              stats: stats,
                              total: totalAmount,
                              palette: _chartPalette,
                              textColor: textColor,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),

                            // List Kategori di Bawah Diagram (tanpa icon)
                            for (var i = 0; i < stats.length; i++) ...[
                              _categoryListItem(
                                stat: stats[i],
                                color: _chartPalette[i % _chartPalette.length],
                                totalPeriod: totalAmount,
                                period: period,
                                textColor: textColor,
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required String amount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$label ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 2.5,
              color: isSelected ? const Color(0xFFFF5252) : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryListItem({
    required CategoryStat stat,
    required Color color,
    required int totalPeriod,
    required StatPeriod period,
    required Color textColor,
  }) {
    final pct = totalPeriod > 0 ? (stat.total * 100 / totalPeriod) : 0.0;

    return InkWell(
      onTap: () => _showDetail(context, stat, period, _selectedType),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Badge Persentase Berwarna
            Container(
              width: 46,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '${pct.round()}%',
                style: TextStyle(
                  color: color.computeLuminance() > 0.4
                      ? const Color(0xFF1E2025)
                      : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Nama Kategori (tanpa icon sesuai permintaan)
            Expanded(
              child: Text(
                stat.category.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Nominal Rupiah
            Text(
              '${rupiah(stat.total)},00',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    CategoryStat stat,
    StatPeriod period,
    String type,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: Color(stat.category.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${stat.category.name} · ${period.label}',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RepoFuture<List<TxItem>>(
                keyValue: (stat.category.id, period),
                load: (repo) => repo.transactions(
                  period.from,
                  period.to,
                  categoryId: stat.category.id,
                  type: type,
                ),
                builder: (context, items) => ListView(
                  children: groupedTxWidgets(context, items, null),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalloutItem {
  final int index;
  final String name;
  final double percentage;
  final Color color;
  final double midAngle;
  final Offset pEdge;
  final Offset pOut;
  final bool isRight;
  double targetY;
  late TextPainter textPainter;

  _CalloutItem({
    required this.index,
    required this.name,
    required this.percentage,
    required this.color,
    required this.midAngle,
    required this.pEdge,
    required this.pOut,
    required this.isRight,
    required this.targetY,
  });
}

class _PieChartWithCallouts extends StatelessWidget {
  final List<CategoryStat> stats;
  final int total;
  final List<Color> palette;
  final Color textColor;
  final bool isDark;

  const _PieChartWithCallouts({
    required this.stats,
    required this.total,
    required this.palette,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Memberi tinggi yang cukup untuk diagram dan label callout
        final h = (w * 0.72).clamp(260.0, 320.0);
        return SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: _PieChartPainter(
              stats: stats,
              total: total,
              palette: palette,
              textColor: textColor,
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<CategoryStat> stats;
  final int total;
  final List<Color> palette;
  final Color textColor;
  final bool isDark;

  _PieChartPainter({
    required this.stats,
    required this.total,
    required this.palette,
    required this.textColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || stats.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    // Radius lingkaran pie yang proporsional sehingga menyisakan ruang callout di kiri dan kanan
    final radius = (size.width * 0.19).clamp(58.0, 78.0);

    // Sudut awal ~ -0.35 * pi (~ -63 derajat, sekitar jam 1)
    // Sesuai screenshot, slice terbesar (Pakaian 36.4%) berada di sisi kanan
    const startAngle = -math.pi * 0.35;

    // 1. Gambar Sektor-Sektor Pie (Solid)
    double currentAngle = startAngle;
    for (var i = 0; i < stats.length; i++) {
      final s = stats[i];
      if (s.total <= 0) continue;
      final sweep = (s.total / total) * 2 * math.pi;
      final color = palette[i % palette.length];

      final slicePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweep,
        true,
        slicePaint,
      );

      // Garis pemisah tipis antar irisan
      final borderPaint = Paint()
        ..color = isDark ? const Color(0xFF1E2025) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweep,
        true,
        borderPaint,
      );

      currentAngle += sweep;
    }

    // 2. Siapkan Callout Items
    final maxLabelWidth = (center.dx - radius - 30).clamp(65.0, 110.0);
    final leftItems = <_CalloutItem>[];
    final rightItems = <_CalloutItem>[];

    currentAngle = startAngle;
    // Tampilkan label callout maksimal untuk 9 kategori teratas agar rapi dan tidak tumpang tindih
    final maxCallouts = math.min(stats.length, 9);

    for (var i = 0; i < stats.length; i++) {
      final s = stats[i];
      final sweep = (s.total / total) * 2 * math.pi;
      final midAngle = currentAngle + sweep / 2;
      currentAngle += sweep;

      if (i >= maxCallouts || s.total <= 0) continue;

      final pct = (s.total * 100) / total;
      final color = palette[i % palette.length];

      final pEdge = Offset(
        center.dx + radius * math.cos(midAngle),
        center.dy + radius * math.sin(midAngle),
      );
      final pOut = Offset(
        center.dx + (radius + 12) * math.cos(midAngle),
        center.dy + (radius + 12) * math.sin(midAngle),
      );

      final isRight = math.cos(midAngle) >= 0;

      final displayName = s.category.name.length > 15
          ? '${s.category.name.substring(0, 13)}...'
          : s.category.name;

      final textSpan = TextSpan(
        children: [
          TextSpan(
            text: '$displayName\n',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          TextSpan(
            text: '${pct.toStringAsFixed(1)} %',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.normal,
              height: 1.25,
            ),
          ),
        ],
      );

      final tp = TextPainter(
        text: textSpan,
        textAlign: isRight ? TextAlign.left : TextAlign.right,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      );
      tp.layout(maxWidth: maxLabelWidth);

      final item = _CalloutItem(
        index: i,
        name: displayName,
        percentage: pct,
        color: color,
        midAngle: midAngle,
        pEdge: pEdge,
        pOut: pOut,
        isRight: isRight,
        targetY: pOut.dy,
      )..textPainter = tp;

      if (isRight) {
        rightItems.add(item);
      } else {
        leftItems.add(item);
      }
    }

    // 3. Resolusi Tabrakan Vertikal (2-Pass Relaxation)
    _relaxCallouts(leftItems, size.height);
    _relaxCallouts(rightItems, size.height);

    // 4. Gambar Leader Lines dan Teks Callout
    for (final item in [...leftItems, ...rightItems]) {
      final linePaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (item.isRight) {
        final elbowX = math.max(item.pOut.dx + 4, center.dx + radius + 14);
        final pElbow = Offset(elbowX, item.targetY);
        final pEnd = Offset(
          math.min(elbowX + 12, size.width - item.textPainter.width - 6),
          item.targetY,
        );

        final path = Path()
          ..moveTo(item.pEdge.dx, item.pEdge.dy)
          ..lineTo(item.pOut.dx, item.pOut.dy)
          ..lineTo(pElbow.dx, pElbow.dy)
          ..lineTo(pEnd.dx, pEnd.dy);

        canvas.drawPath(path, linePaint);

        item.textPainter.paint(
          canvas,
          Offset(pEnd.dx + 4, item.targetY - item.textPainter.height / 2),
        );
      } else {
        final elbowX = math.min(item.pOut.dx - 4, center.dx - radius - 14);
        final pElbow = Offset(elbowX, item.targetY);
        final pEnd = Offset(
          math.max(elbowX - 12, item.textPainter.width + 6),
          item.targetY,
        );

        final path = Path()
          ..moveTo(item.pEdge.dx, item.pEdge.dy)
          ..lineTo(item.pOut.dx, item.pOut.dy)
          ..lineTo(pElbow.dx, pElbow.dy)
          ..lineTo(pEnd.dx, pEnd.dy);

        canvas.drawPath(path, linePaint);

        item.textPainter.paint(
          canvas,
          Offset(
            pEnd.dx - 4 - item.textPainter.width,
            item.targetY - item.textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _relaxCallouts(List<_CalloutItem> items, double height) {
    if (items.isEmpty) return;
    items.sort((a, b) => a.targetY.compareTo(b.targetY));

    const minGap = 28.0;
    double currentY = 16.0;

    // Pass 1: Dari atas ke bawah
    for (final item in items) {
      if (item.targetY < currentY) {
        item.targetY = currentY;
      }
      currentY = item.targetY + minGap;
    }

    // Pass 2: Dari bawah ke atas jika melebihi batas bawah canvas
    final maxY = height - 16.0;
    if (items.last.targetY > maxY) {
      items.last.targetY = maxY;
      for (var k = items.length - 2; k >= 0; k--) {
        if (items[k].targetY > items[k + 1].targetY - minGap) {
          items[k].targetY = items[k + 1].targetY - minGap;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.stats != stats ||
        oldDelegate.total != total ||
        oldDelegate.textColor != textColor ||
        oldDelegate.isDark != isDark;
  }
}
