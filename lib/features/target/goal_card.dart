import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'alokasi_dialog.dart';
import 'goal_detail_page.dart';
import 'goal_form_page.dart';
import 'target_icons.dart';

class GoalCard extends StatelessWidget {
  final SavingsGoal goal;

  const GoalCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goalColor = Color(goal.color);
    final isCompleted = goal.isCompleted;
    final isOverdue = goal.isOverdue;
    final percent = goal.progressPercent;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E232A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.4)
              : (isOverdue
                  ? Colors.redAccent.withValues(alpha: 0.4)
                  : (isDark ? Colors.white12 : Colors.black12)),
          width: isCompleted || isOverdue ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GoalDetailPage(goalId: goal.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: goalColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(getGoalIcon(goal.icon), color: goalColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (goal.assetName != null) ...[
                              Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                goal.assetName!,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              goal.hasDeadline ? Icons.event_outlined : Icons.all_inclusive,
                              size: 12,
                              color: isOverdue ? Colors.redAccent : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                goal.deadlineStatusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isOverdue ? Colors.redAccent : (isCompleted ? Colors.green : Colors.grey.shade600),
                                  fontWeight: isOverdue || isCompleted ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Menu Dropdown Opsi
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    onSelected: (val) async {
                      if (val == 'edit') {
                        openGoalForm(context, edit: goal);
                      } else if (val == 'deadline') {
                        showDeadlineOptionsDialog(context, goal);
                      } else if (val == 'transfer') {
                        showPindahSaldoDialog(context, goal);
                      } else if (val == 'toggle_status') {
                        final newStatus = goal.status == 'completed' ? 'active' : 'completed';
                        await repo.updateGoalStatus(goal.id, newStatus);
                      } else if (val == 'delete') {
                        final ok = await confirm(
                          context,
                          title: 'Hapus Target?'.tr,
                          message: 'Target "${goal.title}" akan dihapus permanen.',
                          okLabel: 'Hapus'.tr,
                        );
                        if (ok) {
                          await repo.deleteSavingsGoal(goal.id);
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text('Ubah Target'.tr),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'deadline',
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text('Pilihan Batas Waktu'.tr),
                          ],
                        ),
                      ),
                      if (goal.currentAmount > 0)
                        PopupMenuItem(
                          value: 'transfer',
                          child: Row(
                            children: [
                              const Icon(Icons.swap_horiz, size: 18, color: Colors.purple),
                              const SizedBox(width: 8),
                              Text('Pindahkan Saldo'.tr),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Row(
                          children: [
                            Icon(
                              isCompleted ? Icons.restart_alt : Icons.check_circle_outline,
                              size: 18,
                              color: isCompleted ? Colors.orange : Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            Text(isCompleted ? 'Buka Kembali'.tr : 'Tandai Selesai'.tr),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Text('Hapus'.tr, style: const TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Baris Nominal & Persentase
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  RichText(
                    text: TextSpan(
                      text: rupiah(goal.currentAmount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: goalColor,
                      ),
                      children: [
                        TextSpan(
                          text: ' / ${rupiah(goal.targetAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.15)
                          : (isOverdue
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : goalColor.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCompleted ? 'Tercapai 🎉'.tr : '$percent%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? Colors.green
                            : (isOverdue ? Colors.redAccent : goalColor),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? Colors.green : (isOverdue ? Colors.redAccent : goalColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Info Sisa Kekurangan & Tombol Cepat Batas Waktu jika Overdue
              if (isOverdue) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Deadline habis ($percent% tercapai). Ketuk opsi untuk perpanjang atau selesai.',
                          style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                        ),
                      ),
                      InkWell(
                        onTap: () => showDeadlineOptionsDialog(context, goal),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Pilihan'.tr,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCompleted
                          ? 'Target berhasil dipenuhi 100%!'.tr
                          : '${'Kurang'.tr} ${rupiah(goal.remainingAmount)} lagi',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCompleted ? Colors.green : (isDark ? Colors.white60 : Colors.black54),
                        fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (goal.hasDeadline && !isCompleted && goal.daysRemaining != null && goal.daysRemaining! > 0)
                      Text(
                        '~${rupiah((goal.remainingAmount / goal.daysRemaining!).ceil())}/hari',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Tombol Aksi Menabung & Tarik
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (goal.currentAmount > 0) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => showTarikDanaDialog(context, goal),
                      icon: const Icon(Icons.remove, size: 14),
                      label: Text('Tarik'.tr, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: goalColor,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => showAlokasiDanaDialog(context, goal),
                    icon: const Icon(Icons.add, size: 14),
                    label: Text('Menabung'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
