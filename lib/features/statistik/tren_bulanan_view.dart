import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

class TrenBulananView extends StatefulWidget {
  final int? filterAssetId;
  final int? filterTagId;
  final Widget filterBar;

  const TrenBulananView({
    super.key,
    required this.filterAssetId,
    required this.filterTagId,
    required this.filterBar,
  });

  @override
  State<TrenBulananView> createState() => _TrenBulananViewState();
}

class _TrenBulananViewState extends State<TrenBulananView> {
  int _year = DateTime.now().year;
  String _chartMetric = 'both'; // 'both', 'expense', 'income'
  int? _selectedMonth; // 1..12 or null

  void _shiftYear(int delta) {
    setState(() {
      _year += delta;
      _selectedMonth = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return RepoFuture<Map<int, Totals>>(
      keyValue: (_year, widget.filterAssetId, widget.filterTagId),
      load: (repo) => repo.monthlyTotals(
        _year,
        assetId: widget.filterAssetId,
        tagId: widget.filterTagId,
      ),
      builder: (context, monthlyData) {
        // Hitung total tahunan & rata-rata
        int totalIncome = 0;
        int totalExpense = 0;
        int maxMonthly = 0;

        for (int m = 1; m <= 12; m++) {
          final t = monthlyData[m] ?? const Totals(0, 0);
          totalIncome += t.income;
          totalExpense += t.expense;
          if (t.income > maxMonthly) maxMonthly = t.income;
          if (t.expense > maxMonthly) maxMonthly = t.expense;
        }

        final netSavings = totalIncome - totalExpense;
        final avgExpense = (totalExpense / 12).round();
        final avgIncome = (totalIncome / 12).round();

        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // 1. Navigasi Tahun: < 2026 >
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _shiftYear(-1),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_left, size: 24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_year',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _shiftYear(1),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_right, size: 24),
                        ),
                      ),
                    ],
                  ),

                  // Segmented Pilihan Tampilan Bar
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'both', label: Text('Semua'.tr, style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'expense', label: Text('Keluar'.tr, style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'income', label: Text('Masuk'.tr, style: const TextStyle(fontSize: 12))),
                    ],
                    selected: {_chartMetric},
                    onSelectionChanged: (set) => setState(() => _chartMetric = set.first),
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),

            // Filter Bar (Aset & Tag)
            widget.filterBar,

            // 2. Kartu Ringkasan Tahunan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      label: 'Total Pengeluaran'.tr,
                      amount: rupiah(totalExpense),
                      color: Colors.redAccent,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryItem(
                      label: 'Total Pendapatan'.tr,
                      amount: rupiah(totalIncome),
                      color: Colors.green,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      label: 'Tabungan Bersih'.tr,
                      amount: '${netSavings >= 0 ? '+' : ''}${rupiah(netSavings)}',
                      color: netSavings >= 0 ? Colors.teal : Colors.orangeAccent,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryItem(
                      label: 'Rata-rata Keluar / Bln'.tr,
                      amount: rupiah(avgExpense),
                      color: theme.colorScheme.primary,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Diagram Batang Tren Bulanan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grafik Tren Jan - Des',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Row(
                            children: [
                              if (_chartMetric != 'expense') ...[
                                _legendDot(Colors.green, 'Masuk'),
                                const SizedBox(width: 10),
                              ],
                              if (_chartMetric != 'income') ...[
                                _legendDot(Colors.redAccent, 'Keluar'),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Canvas Bar Chart
                      SizedBox(
                        height: 220,
                        child: _MonthlyBarChart(
                          data: monthlyData,
                          maxVal: maxMonthly,
                          metric: _chartMetric,
                          selectedMonth: _selectedMonth,
                          onMonthSelected: (m) => setState(() {
                            _selectedMonth = _selectedMonth == m ? null : m;
                          }),
                          avgExpense: avgExpense,
                          avgIncome: avgIncome,
                          isDark: isDark,
                        ),
                      ),

                      if (_selectedMonth != null) ...[
                        const Divider(height: 24),
                        _buildSelectedMonthDetails(
                          _selectedMonth!,
                          monthlyData[_selectedMonth!] ?? const Totals(0, 0),
                          theme,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 4. Rincian Tabel Bulan per Bulan
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'RINCIAN BULAN KE BULAN',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 12,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  itemBuilder: (context, i) {
                    final monthIndex = i + 1;
                    final t = monthlyData[monthIndex] ?? const Totals(0, 0);
                    final diff = t.income - t.expense;
                    final isHighlighted = _selectedMonth == monthIndex;

                    return InkWell(
                      onTap: () => setState(() {
                        _selectedMonth = isHighlighted ? null : monthIndex;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isHighlighted
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                bulanPendek[i],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isHighlighted ? theme.colorScheme.primary : textColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '+${rupiah(t.income)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        '-${rupiah(t.expense)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${diff >= 0 ? '+' : ''}${rupiah(diff)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: diff >= 0 ? Colors.teal : Colors.orangeAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String amount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSelectedMonthDetails(int month, Totals t, ThemeData theme) {
    final diff = t.income - t.expense;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detail ${bulan[month - 1]} $_year',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Arus Kas: ${diff >= 0 ? '+' : ''}${rupiah(diff)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: diff >= 0 ? Colors.teal : Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pendapatan: ${rupiah(t.income)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
              Text('Pengeluaran: ${rupiah(t.expense)}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final Map<int, Totals> data;
  final int maxVal;
  final String metric;
  final int? selectedMonth;
  final ValueChanged<int> onMonthSelected;
  final int avgExpense;
  final int avgIncome;
  final bool isDark;

  const _MonthlyBarChart({
    required this.data,
    required this.maxVal,
    required this.metric,
    required this.selectedMonth,
    required this.onMonthSelected,
    required this.avgExpense,
    required this.avgIncome,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight - 24; // ruang label bulan di bawah
        final barSlotWidth = w / 12;
        final effectiveMax = maxVal > 0 ? maxVal * 1.15 : 1000000.0;

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Garis horizontal grid
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (index) {
                      return Divider(
                        height: 1,
                        color: isDark ? Colors.white10 : Colors.black12,
                      );
                    }),
                  ),

                  // Batang untuk tiap bulan
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(12, (index) {
                      final month = index + 1;
                      final t = data[month] ?? const Totals(0, 0);
                      final isSelected = selectedMonth == month;

                      final incHeight = (t.income / effectiveMax * h).clamp(0.0, h);
                      final expHeight = (t.expense / effectiveMax * h).clamp(0.0, h);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onMonthSelected(month),
                        child: Container(
                          width: barSlotWidth,
                          height: double.infinity,
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (metric != 'expense')
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: metric == 'both' ? 8 : 14,
                                      height: math.max(incHeight, 2.0),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.green
                                            : Colors.green.withValues(alpha: 0.8),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.green.withValues(alpha: 0.4),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                    ),
                                  if (metric == 'both') const SizedBox(width: 2),
                                  if (metric != 'income')
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: metric == 'both' ? 8 : 14,
                                      height: math.max(expHeight, 2.0),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.redAccent
                                            : Colors.redAccent.withValues(alpha: 0.8),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.redAccent.withValues(alpha: 0.4),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // Label Bulan (Jan - Des)
            SizedBox(
              height: 24,
              child: Row(
                children: List.generate(12, (index) {
                  final month = index + 1;
                  final isSelected = selectedMonth == month;
                  return Expanded(
                    child: Center(
                      child: Text(
                        bulanPendek[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.teal : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}
