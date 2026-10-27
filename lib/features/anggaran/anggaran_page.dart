import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class AnggaranPage extends StatefulWidget {
  const AnggaranPage({super.key});

  @override
  State<AnggaranPage> createState() => _AnggaranPageState();
}

class _AnggaranPageState extends State<AnggaranPage> {
  DateTime _currentMonth = firstOfMonth(DateTime.now());

  String get _period => periodOf(_currentMonth);

  void _shiftMonth(int dir) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + dir, 1);
    });
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _currentMonth = DateTime(picked.year, picked.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anggaran Pengeluaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Salin anggaran bulan lalu',
            onPressed: () => _copyFromPreviousMonth(context, repo),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSetBudgetDialog(context, repo),
        icon: const Icon(Icons.add),
        label: const Text('Atur Anggaran'),
      ),
      body: Column(
        children: [
          // Navigasi Bulan: < Oktober 2026 >
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Bulan sebelumnya',
                  onPressed: () => _shiftMonth(-1),
                ),
                GestureDetector(
                  onTap: () => _pickMonth(context),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        periodLabel(_period),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Bulan berikutnya',
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: RepoFuture<MonthlyBudgetSummary>(
              keyValue: _period,
              load: (r) => r.monthlyBudgetSummary(_period),
              builder: (context, summary) {
                if (summary.items.isEmpty) {
                  return _buildEmptyState(context, repo);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    // Card Ringkasan Total
                    _buildOverviewCard(context, summary, isDark),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Anggaran per Kategori (${summary.items.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showSetBudgetDialog(context, repo),
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('Tambah / Edit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Daftar Kategori
                    for (final item in summary.items)
                      _buildCategoryCard(context, repo, item, isDark),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    MonthlyBudgetSummary summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final isOver = summary.isOverBudget;
    final progress = summary.overallProgress.clamp(0.0, 1.0);

    Color progressColor;
    if (isOver) {
      progressColor = Colors.redAccent;
    } else if (progress > 0.8) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.teal;
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOver
              ? Colors.redAccent.withValues(alpha: 0.5)
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isOver ? Icons.warning_amber_rounded : Icons.savings_outlined,
                      color: progressColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Total Anggaran Bulanan',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOver
                        ? 'Melebihi Anggaran'
                        : (progress > 0.8 ? 'Mendekati Batas' : 'Aman'),
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Baris Angka
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metricColumn(
                  'Batas Anggaran',
                  rupiah(summary.totalBudget),
                  null,
                ),
                _metricColumn(
                  'Terpakai',
                  rupiah(summary.totalSpent),
                  progressColor,
                ),
                _metricColumn(
                  isOver ? 'Kelebihan' : 'Sisa Anggaran',
                  rupiah(summary.totalRemaining.abs()),
                  isOver ? Colors.redAccent : Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOver
                  ? 'Pengeluaran melebihi anggaran sebesar ${rupiah(summary.totalSpent - summary.totalBudget)}'
                  : 'Tersisa ${rupiah(summary.totalRemaining)} (${((1.0 - progress) * 100).toStringAsFixed(1)}% dari total anggaran)',
              style: TextStyle(fontSize: 12, color: progressColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(String label, String value, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Repo repo,
    CategoryBudget item,
    bool isDark,
  ) {
    final isOver = item.isOverBudget;
    final progress = item.progress.clamp(0.0, 1.0);

    Color progressColor;
    if (isOver) {
      progressColor = Colors.redAccent;
    } else if (progress > 0.8) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.teal;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isOver
              ? Colors.redAccent.withValues(alpha: 0.35)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Color(item.category.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.category.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Badge Sisa / Over
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOver
                        ? 'Lebih ${rupiah(item.spentAmount - item.budgetAmount)}'
                        : 'Sisa ${rupiah(item.remaining)}',
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Menu Aksi
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showSetBudgetDialog(
                        context,
                        repo,
                        initialCategory: item.category,
                        initialAmount: item.budgetAmount,
                      );
                    } else if (val == 'delete') {
                      repo.deleteBudget(item.category.id, item.period);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Ubah Anggaran'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Hapus Anggaran', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),

            // Rincian Terpakai & Batas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terpakai ${rupiah(item.spentAmount)} (${(item.progress * 100).toStringAsFixed(1)}%)',
                  style: TextStyle(fontSize: 12, color: progressColor),
                ),
                Text(
                  'Batas ${rupiah(item.budgetAmount)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Repo repo) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.track_changes, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Belum ada anggaran untuk ${periodLabel(_period)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tetapkan batas pengeluaran bulanan per kategori (misal: Makanan Rp 2.000.000/bln) agar keuangan Anda tetap terkendali.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showSetBudgetDialog(context, repo),
              icon: const Icon(Icons.add),
              label: const Text('Atur Anggaran Sekarang'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _copyFromPreviousMonth(context, repo),
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Salin Anggaran Bulan Lalu'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------- DIALOG ATUR ANGGARAN
  Future<void> _showSetBudgetDialog(
    BuildContext context,
    Repo repo, {
    Category? initialCategory,
    int? initialAmount,
  }) async {
    final cats = await repo.categories('expense');
    if (!context.mounted) return;

    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan kategori pengeluaran terlebih dahulu.')),
      );
      return;
    }

    int selectedCatId = initialCategory?.id ?? cats.first.id;
    final amountCtrl = TextEditingController(
      text: initialAmount != null ? formatRibuan(initialAmount) : '',
    );
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(initialCategory != null ? 'Ubah Anggaran' : 'Atur Anggaran Bulanan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Periode: ${periodLabel(_period)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 14),

                // Pilihan Kategori
                if (initialCategory == null)
                  DropdownButtonFormField<int>(
                    initialValue: selectedCatId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Pengeluaran',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: Color(c.color),
                              ),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => selectedCatId = v!),
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(initialCategory.color),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          initialCategory.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Input Nominal Batas Anggaran dengan pemisah ribuan
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandsSeparatorInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Batas Anggaran Bulanan',
                    prefixText: 'Rp ',
                    errorText: error,
                    border: const OutlineInputBorder(),
                    hintText: 'Contoh: 2.000.000',
                  ),
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
                final nominal = parseRibuan(amountCtrl.text);
                if (nominal <= 0) {
                  setState(() => error = 'Nominal harus lebih dari 0.');
                  return;
                }
                Navigator.pop(ctx);
                await repo.setBudget(
                  categoryId: selectedCatId,
                  amount: nominal,
                  period: _period,
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------ SALIN DARI BULAN SEBELUMNYA
  Future<void> _copyFromPreviousMonth(BuildContext context, Repo repo) async {
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    final prevPeriod = periodOf(prevMonth);

    final count = await repo.copyBudgets(prevPeriod, _period);
    if (!context.mounted) return;

    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil menyalin $count anggaran dari ${periodLabel(prevPeriod)}!'),
          backgroundColor: Colors.teal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada anggaran yang ditemukan di ${periodLabel(prevPeriod)}.'),
        ),
      );
    }
  }
}

