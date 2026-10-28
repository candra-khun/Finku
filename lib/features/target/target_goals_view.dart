import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/localization.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'goal_card.dart';
import 'goal_form_page.dart';

class TargetGoalsView extends StatefulWidget {
  const TargetGoalsView({super.key});

  @override
  State<TargetGoalsView> createState() => _TargetGoalsViewState();
}

class _TargetGoalsViewState extends State<TargetGoalsView> {
  // 0 = Aktif, 1 = Tercapai / Selesai
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<SavingsGoal>>(
      future: repo.savingsGoals(),
      builder: (context, snapshot) {
        final allGoals = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final activeGoals = allGoals.where((g) => g.status == 'active').toList();
        final completedGoals = allGoals.where((g) => g.status != 'active').toList();
        final displayedGoals = _filterIndex == 0 ? activeGoals : completedGoals;

        // Hitung total ringkasan
        var totalTarget = 0;
        var totalSaved = 0;
        for (final g in allGoals) {
          totalTarget += g.targetAmount;
          totalSaved += g.currentAmount;
        }
        final overallProgress = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
        final overallPercent = (overallProgress * 100).round();

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // 1. Kartu Ringkasan Keseluruhan
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E2826) : const Color(0xFFE6F4EA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
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
                              const Icon(Icons.savings_rounded, color: Colors.teal, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Total Target Impian'.tr,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$overallPercent% ${'Terkumpul'.tr}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Nominal Terkumpul vs Target
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Terkumpul Saat Ini'.tr,
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rupiah(totalSaved),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Target Nominal'.tr,
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rupiah(totalTarget),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Bar Keseluruhan
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: overallProgress,
                          minHeight: 10,
                          backgroundColor: isDark ? Colors.white12 : Colors.teal.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Statistik Mini
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniStat(
                            label: 'Target Aktif'.tr,
                            value: '${activeGoals.length}',
                            icon: Icons.flag_outlined,
                            color: Colors.teal,
                          ),
                          Container(width: 1, height: 24, color: isDark ? Colors.white12 : Colors.black12),
                          _miniStat(
                            label: 'Target Tercapai'.tr,
                            value: '${completedGoals.length}',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Filter Tab Pilihan: Aktif vs Selesai
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text('${'Aktif'.tr} (${activeGoals.length})'),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('${'Tercapai / Selesai'.tr} (${completedGoals.length})'),
                  ),
                ],
                selected: {_filterIndex},
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (set) {
                  setState(() => _filterIndex = set.first);
                },
              ),

              const SizedBox(height: 16),

              // 3. Daftar Kartu Target
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (displayedGoals.isEmpty)
                _emptyState(context, isDark, _filterIndex == 0)
              else
                for (final goal in displayedGoals)
                  GoalCard(key: ValueKey('goal-${goal.id}'), goal: goal),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, bool isDark, bool isActiveTab) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          Icon(
            isActiveTab ? Icons.flag_outlined : Icons.check_circle_outline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            isActiveTab ? 'Belum Ada Target Menabung'.tr : 'Belum Ada Target yang Selesai'.tr,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            isActiveTab
                ? 'Rencanakan impian Anda (Beli Laptop, Dana Darurat, Liburan) dan kumpulkan dana sedikit demi sedikit.'.tr
                : 'Target yang sudah 100% atau telah Anda tandai selesai akan tersimpan di sini.'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
          if (isActiveTab) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openGoalForm(context),
              icon: const Icon(Icons.add),
              label: Text('Buat Target Sekarang'.tr),
            ),
          ],
        ],
      ),
    );
  }
}

