import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'tren_bulanan_view.dart';

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
  int _subTab = 0; // 0: Kategori, 1: Tren Bulanan
  StatMode _mode = StatMode.month;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _range;
  String _selectedType = 'expense'; // Default Pengeluaran seperti pada gambar

  // Filter Aset dan Tag
  int? _filterAssetId;
  String? _filterAssetName;
  int? _filterTagId;
  String? _filterTagName;

  static const _modeLabelsId = {
    StatMode.month: 'Bulanan',
    StatMode.week: 'Mingguan',
    StatMode.year: 'Tahunan',
    StatMode.range: 'Periode',
  };
  static const _modeLabelsEn = {
    StatMode.month: 'Monthly',
    StatMode.week: 'Weekly',
    StatMode.year: 'Yearly',
    StatMode.range: 'Range',
  };
  Map<StatMode, String> get _modeLabels =>
      AppSettings.instance.isEnglish ? _modeLabelsEn : _modeLabelsId;

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

  Future<void> _pickAssetFilter() async {
    final repo = context.read<Repo>();
    final assets = await repo.assets();
    final nonArchived = assets.where((a) => !a.archived).toList();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Filter Berdasarkan Aset',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('Semua Aset'),
                trailing: _filterAssetId == null
                    ? const Icon(Icons.check, color: Colors.teal)
                    : null,
                onTap: () {
                  setState(() {
                    _filterAssetId = null;
                    _filterAssetName = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: nonArchived.length,
                  itemBuilder: (context, i) {
                    final a = nonArchived[i];
                    final isSelected = a.id == _filterAssetId;
                    return ListTile(
                      leading:
                          const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(a.name),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.teal)
                          : null,
                      onTap: () {
                        setState(() {
                          _filterAssetId = a.id;
                          _filterAssetName = a.name;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTagFilter() async {
    final repo = context.read<Repo>();
    final tags = await repo.tags();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Filter Berdasarkan Tag',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('Semua Tag'),
                trailing: _filterTagId == null
                    ? const Icon(Icons.check, color: Colors.teal)
                    : null,
                onTap: () {
                  setState(() {
                    _filterTagId = null;
                    _filterTagName = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
              if (tags.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Belum ada tag yang dibuat',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tags.length,
                    itemBuilder: (context, i) {
                      final t = tags[i];
                      final isSelected = t.id == _filterTagId;
                      return ListTile(
                        leading: const Icon(Icons.label_outline),
                        title: Text('#${t.name}'),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.teal)
                            : null,
                        onTap: () {
                          setState(() {
                            _filterTagId = t.id;
                            _filterTagName = t.name;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterBar(BuildContext context) {
    final hasAsset = _filterAssetId != null;
    final hasTag = _filterTagId != null;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Filter Aset Chip
            FilterChip(
              avatar: Icon(
                Icons.account_balance_wallet,
                size: 16,
                color: hasAsset ? theme.colorScheme.primary : Colors.grey,
              ),
              label: Text(
                hasAsset ? _filterAssetName! : 'Semua Aset',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasAsset ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: hasAsset,
              onSelected: (_) => _pickAssetFilter(),
              deleteIcon: hasAsset ? const Icon(Icons.close, size: 16) : null,
              onDeleted: hasAsset
                  ? () => setState(() {
                        _filterAssetId = null;
                        _filterAssetName = null;
                      })
                  : null,
            ),
            const SizedBox(width: 8),

            // Filter Tag Chip
            FilterChip(
              avatar: Icon(
                Icons.label,
                size: 16,
                color: hasTag ? theme.colorScheme.primary : Colors.grey,
              ),
              label: Text(
                hasTag ? '#$_filterTagName!' : 'Semua Tag',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasTag ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: hasTag,
              onSelected: (_) => _pickTagFilter(),
              deleteIcon: hasTag ? const Icon(Icons.close, size: 16) : null,
              onDeleted: hasTag
                  ? () => setState(() {
                        _filterTagId = null;
                        _filterTagName = null;
                      })
                  : null,
            ),

            if (hasAsset || hasTag) ...[
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _filterAssetId = null;
                    _filterAssetName = null;
                    _filterTagId = null;
                    _filterTagName = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subTabBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
      child: SegmentedButton<int>(
        segments: [
          ButtonSegment(
            value: 0,
            icon: const Icon(Icons.pie_chart_outline, size: 16),
            label: Text('Kategori'.tr),
          ),
          ButtonSegment(
            value: 1,
            icon: const Icon(Icons.bar_chart_outlined, size: 16),
            label: Text('Tren Bulanan'.tr),
          ),
        ],
        selected: {_subTab},
        onSelectionChanged: (set) => setState(() => _subTab = set.first),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = _period;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _subTabBar(),
            Expanded(
              child: _subTab == 1
                  ? TrenBulananView(
                      filterAssetId: _filterAssetId,
                      filterTagId: _filterTagId,
                      filterBar: _filterBar(context),
                    )
                  : RepoFuture<_StatData>(
                      keyValue: (
                        _selectedType,
                        period,
                        _filterAssetId,
                        _filterTagId
                      ),
                      load: (repo) async {
                        final totals = await repo.totals(
                          period.from,
                          period.to,
                          assetId: _filterAssetId,
                          tagId: _filterTagId,
                        );
                        final stats = await repo.categoryStats(
                          _selectedType,
                          period.from,
                          period.to,
                          assetId: _filterAssetId,
                          tagId: _filterTagId,
                        );
                        return _StatData(totals, stats);
                      },
                      builder: (context, data) {
                        final totals = data.totals;
                        final stats = data.stats;
                        final totalAmount =
                            stats.fold<int>(0, (sum, s) => sum + s.total);

                        return Column(
                          children: [
                            // 1. Baris Navigasi Atas: < Okt 2026 >    Bulanan v
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                          child: Icon(Icons.chevron_left,
                                              size: 24),
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
                                          child: Icon(Icons.chevron_right,
                                              size: 24),
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
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black26,
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
                                          const Icon(Icons.keyboard_arrow_down,
                                              size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Baris Filter Aset & Tag
                            _filterBar(context),

                            // 3. Tab Bar: Pendapatan Rp ...    Pengeluaran Rp ...
                            Row(
                              children: [
                                _tabButton(
                                  label: 'Pendapatan'.tr,
                                  amount: '${rupiah(totals.income)},00',
                                  isSelected: _selectedType == 'income',
                                  onTap: () =>
                                      setState(() => _selectedType = 'income'),
                                ),
                                _tabButton(
                                  label: 'Pengeluaran'.tr,
                                  amount: '${rupiah(totals.expense)},00',
                                  isSelected: _selectedType == 'expense',
                                  onTap: () =>
                                      setState(() => _selectedType = 'expense'),
                                ),
                              ],
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),

                            // 4. Konten: Diagram Pie Solid & List Kategori
                            Expanded(
                              child: stats.isEmpty || totalAmount == 0
                                  ? Center(
                                      child: Text(
                                        (_filterAssetId != null ||
                                                _filterTagId != null)
                                            ? 'Tidak ada transaksi untuk filter yang dipilih.'.tr
                                            : (_selectedType == 'income'
                                                ? 'Belum ada pendapatan pada periode ini.'.tr
                                                : 'Belum ada pengeluaran pada periode ini.'.tr),
                                        style: TextStyle(
                                          color:
                                              textColor.withValues(alpha: 0.5),
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : ListView(
                                      padding:
                                          const EdgeInsets.only(bottom: 24),
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
                                          color: isDark
                                              ? Colors.white10
                                              : Colors.black12,
                                        ),

                                        // List Kategori di Bawah Diagram (tanpa icon)
                                        for (var i = 0;
                                            i < stats.length;
                                            i++) ...[
                                          _categoryListItem(
                                            stat: stats[i],
                                            color: _chartPalette[
                                                i % _chartPalette.length],
                                            totalPeriod: totalAmount,
                                            period: period,
                                            textColor: textColor,
                                          ),
                                          Divider(
                                            height: 1,
                                            thickness: 0.5,
                                            color: isDark
                                                ? Colors.white10
                                                : Colors.black12,
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
          ],
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
  final Offset pStart;
  final bool isRight;
  double targetY;
  late TextPainter textPainter;

  _CalloutItem({
    required this.index,
    required this.name,
    required this.percentage,
    required this.color,
    required this.midAngle,
    required this.pStart,
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
        // Memberi tinggi yang lebih leluasa agar label dan garis callout tidak berdesakan
        final h = (w * 0.78).clamp(280.0, 340.0);
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
    // Radius lingkaran pie yang proporsional sehingga menyisakan ruang callout yang lega di kiri dan kanan
    final radius = (size.width * 0.18).clamp(56.0, 74.0);

    // Sudut awal ~ -0.35 * pi (~ -63 derajat, sekitar jam 1)
    const startAngle = -math.pi * 0.35;

    // 1. Gambar Sektor-Sektor Pie (Solid dengan border pemisah rapi)
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

      // Garis pemisah tipis dan elegan antar irisan
      final borderPaint = Paint()
        ..color = isDark ? const Color(0xFF14171A) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweep,
        true,
        borderPaint,
      );

      currentAngle += sweep;
    }

    // 2. Siapkan Callout Items (Dengan Seleksi Kategori yang Signifikan)
    final maxLabelWidth = (center.dx - radius - 36).clamp(65.0, 110.0);
    final leftItems = <_CalloutItem>[];
    final rightItems = <_CalloutItem>[];

    // Ambang batas: jika total kategori banyak (> 6), filter irisan yang sangat kecil (< 1.8%)
    // agar diagram tidak ruwet dan berdesakan, namun pastikan minimal 5 irisan teratas selalu dapat callout.
    final bool filterMinor = stats.length > 6;

    currentAngle = startAngle;
    for (var i = 0; i < stats.length; i++) {
      final s = stats[i];
      final sweep = (s.total / total) * 2 * math.pi;
      final midAngle = currentAngle + sweep / 2;
      currentAngle += sweep;

      if (s.total <= 0) continue;

      final pct = (s.total * 100) / total;
      if (filterMinor && i >= 6 && pct < 1.8) {
        // Lewati callout garis untuk irisan ekstra kecil yang berhimpitan,
        // rincian lengkap tetap ditampilkan di tabel daftar bawah.
        continue;
      }

      final color = palette[i % palette.length];
      final isRight = math.cos(midAngle) >= 0;

      // Titik awal tepat di tepi lingkaran pie (+ 2px untuk estetika)
      final pStart = Offset(
        center.dx + (radius + 2.0) * math.cos(midAngle),
        center.dy + (radius + 2.0) * math.sin(midAngle),
      );

      final displayName = s.category.name.length > 14
          ? '${s.category.name.substring(0, 12)}...'
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
            text: '${pct.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isDark ? const Color(0xFFB0B7C3) : const Color(0xFF555E6D),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
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
        pStart: pStart,
        isRight: isRight,
        targetY: pStart.dy,
      )..textPainter = tp;

      if (isRight) {
        rightItems.add(item);
      } else {
        leftItems.add(item);
      }
    }

    // 3. Sorting Monotonik: Wajib diurutkan dari atas ke bawah (pStart.dy)
    // Ini menjamin secara matematis bahwa garis TIDAK AKAN PERNAH BERSILANGAN.
    rightItems.sort((a, b) => a.pStart.dy.compareTo(b.pStart.dy));
    leftItems.sort((a, b) => a.pStart.dy.compareTo(b.pStart.dy));

    // 4. Distribusi Vertikal Callouts (Mencegah Overlap Teks & Label)
    _distributeCallouts(rightItems, size.height);
    _distributeCallouts(leftItems, size.height);

    // 5. Gambar Leader Lines yang Rapi, Dot Indikator, dan Teks
    _drawCalloutGroup(canvas, size, center, radius, rightItems, isRight: true);
    _drawCalloutGroup(canvas, size, center, radius, leftItems, isRight: false);
  }

  void _drawCalloutGroup(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    List<_CalloutItem> items, {
    required bool isRight,
  }) {
    if (items.isEmpty) return;

    // Kolom siku lurus vertikal yang sejajar
    final elbowX = isRight ? center.dx + radius + 22.0 : center.dx - radius - 22.0;

    for (final item in items) {
      final linePaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final dotPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      // Gambar dot pin kecil di tepi irisan pie
      canvas.drawCircle(item.pStart, 2.0, dotPaint);

      final pElbow = Offset(elbowX, item.targetY);

      if (isRight) {
        final pEnd = Offset(
          math.min(elbowX + 14.0, size.width - item.textPainter.width - 4.0),
          item.targetY,
        );

        final path = Path()
          ..moveTo(item.pStart.dx, item.pStart.dy)
          ..lineTo(pElbow.dx, pElbow.dy)
          ..lineTo(pEnd.dx, pEnd.dy);

        canvas.drawPath(path, linePaint);

        item.textPainter.paint(
          canvas,
          Offset(pEnd.dx + 4.0, item.targetY - item.textPainter.height / 2),
        );
      } else {
        final pEnd = Offset(
          math.max(elbowX - 14.0, item.textPainter.width + 4.0),
          item.targetY,
        );

        final path = Path()
          ..moveTo(item.pStart.dx, item.pStart.dy)
          ..lineTo(pElbow.dx, pElbow.dy)
          ..lineTo(pEnd.dx, pEnd.dy);

        canvas.drawPath(path, linePaint);

        item.textPainter.paint(
          canvas,
          Offset(
            pEnd.dx - 4.0 - item.textPainter.width,
            item.targetY - item.textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _distributeCallouts(List<_CalloutItem> items, double canvasHeight) {
    if (items.isEmpty) return;

    const minGap = 30.0; // Jarak vertikal aman antar baris label
    final totalNeeded = (items.length - 1) * minGap;

    // Rata-rata titik Y awal irisan
    final avgStartY = items.map((e) => e.pStart.dy).reduce((a, b) => a + b) / items.length;

    // Awal distribusi Y di sekitar rata-rata posisi pie
    var startY = (avgStartY - totalNeeded / 2).clamp(16.0, canvasHeight - totalNeeded - 16.0);

    for (var i = 0; i < items.length; i++) {
      items[i].targetY = startY + i * minGap;
    }

    // Koreksi batas atas dan bawah secara halus
    if (items.last.targetY > canvasHeight - 16.0) {
      items.last.targetY = canvasHeight - 16.0;
      for (var k = items.length - 2; k >= 0; k--) {
        if (items[k].targetY > items[k + 1].targetY - minGap) {
          items[k].targetY = items[k + 1].targetY - minGap;
        }
      }
    }
    if (items.first.targetY < 16.0) {
      items.first.targetY = 16.0;
      for (var k = 1; k < items.length; k++) {
        if (items[k].targetY < items[k - 1].targetY + minGap) {
          items[k].targetY = items[k - 1].targetY + minGap;
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
