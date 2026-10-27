import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'alokasi_dialog.dart';
import 'goal_form_page.dart';
import 'target_icons.dart';

class GoalDetailPage extends StatelessWidget {
  final int goalId;

  const GoalDetailPage({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<SavingsGoal?>(
      future: repo.getSavingsGoal(goalId),
      builder: (context, snapshot) {
        final goal = snapshot.data;
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Target')),
            body: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : const Center(child: Text('Target tidak ditemukan atau telah dihapus.')),
          );
        }

        final goalColor = Color(goal.color);
        final percent = goal.progressPercent;
        final isCompleted = goal.isCompleted;
        final isOverdue = goal.isOverdue;

        return Scaffold(
          appBar: AppBar(
            title: Text(goal.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Ubah Target',
                onPressed: () => openGoalForm(context, edit: goal),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'deadline') {
                    showDeadlineOptionsDialog(context, goal);
                  } else if (value == 'transfer') {
                    showPindahSaldoDialog(context, goal);
                  } else if (value == 'toggle_status') {
                    final newStatus = goal.status == 'completed' ? 'active' : 'completed';
                    await repo.updateGoalStatus(goal.id, newStatus);
                  } else if (value == 'delete') {
                    final ok = await confirm(
                      context,
                      title: 'Hapus Target Menabung?',
                      message: 'Target "${goal.title}" akan dihapus permanen beserta seluruh riwayat alokasinya.',
                      okLabel: 'Hapus',
                    );
                    if (ok) {
                      await repo.deleteSavingsGoal(goal.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'deadline',
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 20, color: Colors.blue),
                        SizedBox(width: 10),
                        Text('Pilihan Batas Waktu'),
                      ],
                    ),
                  ),
                  if (goal.currentAmount > 0)
                    const PopupMenuItem(
                      value: 'transfer',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 20, color: Colors.purple),
                          SizedBox(width: 10),
                          Text('Pindahkan Saldo'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'toggle_status',
                    child: Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.restart_alt : Icons.check_circle_outline,
                          size: 20,
                          color: isCompleted ? Colors.orange : Colors.teal,
                        ),
                        const SizedBox(width: 10),
                        Text(isCompleted ? 'Buka Kembali Target' : 'Tandai Selesai'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Hapus Target', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Kartu Ringkasan Utama
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E232A) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: goalColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(getGoalIcon(goal.icon), color: goalColor, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(height: 4),
                                if (goal.assetName != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Terhubung: ${goal.assetName}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  goal.hasDeadline ? 'Target: ${tglPanjang(goal.targetDate!)}' : 'Tanpa batas waktu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOverdue ? Colors.redAccent : Colors.grey,
                                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Progres Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                rupiah(goal.currentAmount),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: goalColor,
                                ),
                              ),
                              Text(
                                'dari ${rupiah(goal.targetAmount)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: goal.progress,
                              minHeight: 12,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted ? Colors.green : (isOverdue ? Colors.redAccent : goalColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isCompleted ? 'Target Tercapai (100%)' : 'Kurang ${rupiah(goal.remainingAmount)} lagi',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted ? Colors.green : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: goalColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$percent%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: goalColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (goal.note.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            goal.note,
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Banner Peringatan jika Batas Waktu Habis namun Belum 100%
              if (isOverdue) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Batas Waktu Telah Berakhir (${goal.deadlineStatusLabel})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Target belum sepenuhnya tercapai ($percent% terkumpul). Anda dapat memperpanjang batas waktu, menganggap selesai dengan nominal yang ada, atau memindahkan saldo ke target lain.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => showDeadlineOptionsDialog(context, goal),
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text('Kelola Batas Waktu', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Rekomendasi Menabung Harian / Mingguan (Jika aktif dan ada deadline di masa depan)
              if (!isCompleted && !isOverdue && goal.hasDeadline && goal.daysRemaining != null && goal.daysRemaining! > 0) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.teal.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.teal, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rekomendasi Rencana Menabung',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sisa ${goal.daysRemaining} hari lagi. Tabung sekitar ${rupiah((goal.remainingAmount / goal.daysRemaining!).ceil())}/hari atau ${rupiah((goal.remainingAmount / (goal.daysRemaining! / 7).clamp(1, 999)).ceil())}/minggu untuk mencapai target.',
                                style: const TextStyle(fontSize: 12, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Tombol Aksi Cepat
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: goalColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => showAlokasiDanaDialog(context, goal),
                      icon: const Icon(Icons.add),
                      label: const Text('Menabung (+)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (goal.currentAmount > 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => showTarikDanaDialog(context, goal),
                        icon: const Icon(Icons.remove),
                        label: const Text('Tarik Saldo'),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Riwayat Mutasi Tabungan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Alokasi Dana',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: () => showPindahSaldoDialog(context, goal),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Pindah', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              FutureBuilder<List<GoalAllocation>>(
                future: repo.goalAllocations(goal.id),
                builder: (context, allocSnap) {
                  final list = allocSnap.data ?? [];
                  if (allocSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  }

                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E232A) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.history_outlined, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text(
                            'Belum ada riwayat alokasi dana.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ketuk tombol "Menabung (+)" untuk menyetor dana pertama Anda!',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E232A) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      itemBuilder: (ctx, i) {
                        final item = list[i];
                        final isDeposit = item.isDeposit;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: isDeposit
                                ? Colors.teal.withValues(alpha: 0.15)
                                : Colors.orange.withValues(alpha: 0.15),
                            child: Icon(
                              isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              size: 18,
                              color: isDeposit ? Colors.teal : Colors.orange,
                            ),
                          ),
                          title: Text(
                            item.note.isNotEmpty ? item.note : (isDeposit ? 'Setoran Tabungan' : 'Penarikan Dana'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${tglPanjang(item.date)}${item.assetName != null ? " • ${item.assetName}" : ""}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          trailing: Text(
                            '${isDeposit ? "+" : ""}${rupiah(item.amount)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDeposit ? Colors.teal : Colors.orange,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
