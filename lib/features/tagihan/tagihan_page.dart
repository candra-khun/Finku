import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'tagihan_form_page.dart';

class TagihanPage extends StatefulWidget {
  const TagihanPage({super.key});

  @override
  State<TagihanPage> createState() => _TagihanPageState();
}

class _TagihanPageState extends State<TagihanPage> {
  String _filter = 'all'; // 'all', 'due', 'auto', 'inactive'

  Future<void> _openForm([RecurringTx? item]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TagihanFormPage(initial: item)),
    );
    if (ok == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _payNow(RecurringTx item) async {
    final repo = context.read<Repo>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catat transaksi untuk tagihan "${item.title}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nominal:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(rupiah(item.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rekening:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(item.assetName ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tanggal:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(tglPendek(DateTime.now()), style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Setelah dicatat, tanggal jatuh tempo akan otomatis dimajukan ke periode berikutnya.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bayar & Catat'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await repo.recordRecurringTx(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran "${item.title}" berhasil dicatat!'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _deleteItem(RecurringTx item) async {
    final repo = context.read<Repo>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi Berulang?'),
        content: Text('Hapus pengingat "${item.title}"? Transaksi yang sudah pernah dicatat sebelumnya tidak akan terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await repo.deleteRecurring(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengingat berhasil dihapus'), behavior: SnackBarBehavior.floating),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Berulang & Tagihan'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Tagihan'),
      ),
      body: FutureBuilder<List<RecurringTx>>(
        future: repo.recurringList(),
        builder: (context, snap) {
          final allItems = snap.data ?? [];

          // Hitung ringkasan
          final activeItems = allItems.where((i) => i.isActive).toList();
          final dueItems = activeItems.where((i) => i.isOverdue || i.isDueToday || i.daysUntilDue <= 3).toList();
          final int monthlyExpenseEstimate = activeItems
              .where((i) => i.type == 'expense')
              .fold<int>(0, (sum, i) => sum + i.amount);

          // Filter
          List<RecurringTx> displayed;
          switch (_filter) {
            case 'due':
              displayed = dueItems;
              break;
            case 'auto':
              displayed = activeItems.where((i) => i.autoRecord).toList();
              break;
            case 'inactive':
              displayed = allItems.where((i) => !i.isActive).toList();
              break;
            case 'all':
            default:
              displayed = allItems;
              break;
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Ringkasan Kartu
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estimasi Tagihan Bulanan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                rupiah(monthlyExpenseEstimate),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${activeItems.length} Aktif',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (dueItems.isNotEmpty) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${dueItems.length} tagihan perlu diperhatikan / jatuh tempo segera',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orangeAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Semua (${allItems.length})'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Perlu Bayar (${dueItems.length})'),
                      selected: _filter == 'due',
                      onSelected: (_) => setState(() => _filter = 'due'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Otomatis (${activeItems.where((i) => i.autoRecord).length})'),
                      selected: _filter == 'auto',
                      onSelected: (_) => setState(() => _filter = 'auto'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Nonaktif (${allItems.where((i) => !i.isActive).length})'),
                      selected: _filter == 'inactive',
                      onSelected: (_) => setState(() => _filter = 'inactive'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (displayed.isEmpty) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_repeat, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'Tidak ada transaksi berulang',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Buat pengingat tagihan kosan, internet, atau langganan rutin Anda',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                for (final item in displayed) _buildRecurringCard(context, item, isDark),
              ],

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecurringCard(BuildContext context, RecurringTx item, bool isDark) {
    final theme = Theme.of(context);

    // Status Badge
    Color statusBg;
    Color statusColor;
    String statusText;

    if (!item.isActive) {
      statusBg = Colors.grey.withValues(alpha: 0.15);
      statusColor = Colors.grey;
      statusText = 'Nonaktif';
    } else if (item.isOverdue) {
      statusBg = Colors.redAccent.withValues(alpha: 0.15);
      statusColor = Colors.redAccent;
      statusText = 'Lewat ${item.daysUntilDue.abs()} hari';
    } else if (item.isDueToday) {
      statusBg = Colors.orangeAccent.withValues(alpha: 0.15);
      statusColor = Colors.orangeAccent;
      statusText = 'Jatuh tempo hari ini!';
    } else if (item.daysUntilDue <= 3) {
      statusBg = Colors.amber.withValues(alpha: 0.15);
      statusColor = Colors.amber.shade800;
      statusText = '${item.daysUntilDue} hari lagi';
    } else {
      statusBg = Colors.teal.withValues(alpha: 0.12);
      statusColor = Colors.teal;
      statusText = '${item.daysUntilDue} hari lagi';
    }

    final isExpense = item.type == 'expense';
    final isIncome = item.type == 'income';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isOverdue
              ? Colors.redAccent.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Atas: Judul, Status & Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: item.categoryColor != null
                      ? Color(item.categoryColor!).withValues(alpha: 0.15)
                      : (isExpense
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : isIncome
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.blue.withValues(alpha: 0.15)),
                  child: Icon(
                    isExpense
                        ? Icons.arrow_upward
                        : isIncome
                            ? Icons.arrow_downward
                            : Icons.swap_horiz,
                    color: item.categoryColor != null
                        ? Color(item.categoryColor!)
                        : (isExpense
                            ? Colors.redAccent
                            : isIncome
                                ? Colors.green
                                : Colors.blue),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (item.categoryName != null) ...[
                            Text(
                              item.categoryName!,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                          ],
                          Text(
                            item.assetName ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openForm(item);
                    } else if (val == 'toggle') {
                      context.read<Repo>().toggleRecurringActive(item.id, !item.isActive);
                      setState(() {});
                    } else if (val == 'delete') {
                      _deleteItem(item);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(item.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Hapus', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Baris Tengah: Jadwal & Nominal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.autoRecord ? Icons.autorenew : Icons.calendar_today_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.frequencyLabel} (Tgl ${tglPendek(item.nextDueDate)})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (item.autoRecord) ...[
                      const SizedBox(height: 2),
                      const Text(
                        '⚡ Otomatis dicatat',
                        style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                Text(
                  rupiah(item.amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isExpense
                        ? Colors.redAccent
                        : isIncome
                            ? Colors.green
                            : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            // Tombol Tindakan Cepat (Bayar Sekarang) jika aktif dan manual
            if (item.isActive && !item.autoRecord) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _payNow(item),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Bayar / Catat Sekarang'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(38),
                  side: BorderSide(
                    color: item.isOverdue || item.isDueToday ? Colors.orangeAccent : Colors.teal,
                  ),
                  foregroundColor: item.isOverdue || item.isDueToday ? Colors.orangeAccent : Colors.teal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

