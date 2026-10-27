import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Dialog untuk Menabung / Alokasi Dana ke Target
Future<bool?> showAlokasiDanaDialog(BuildContext context, SavingsGoal goal) async {
  final repo = context.read<Repo>();
  final assets = await repo.assets();
  if (assets.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada akun aset. Buat aset terlebih dahulu.')),
      );
    }
    return false;
  }

  if (!context.mounted) return false;

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  int? selectedAssetId = goal.assetId ?? (assets.isNotEmpty ? assets.first.id : null);
  bool recordTx = true;
  DateTime date = DateTime.now();

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          void setQuickAmount(int val) {
            amountCtrl.text = formatRibuan(val);
            setState(() {});
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(goal.color).withValues(alpha: 0.15),
                  child: Icon(Icons.add_card_rounded, color: Color(goal.color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Alokasi Tabungan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        goal.title,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input Nominal
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Nominal Tabungan',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Sisa kekurangan: ${rupiah(goal.remainingAmount)}',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        label: const Text('+50 rb', style: TextStyle(fontSize: 11)),
                        onPressed: () => setQuickAmount(50000),
                      ),
                      ActionChip(
                        label: const Text('+100 rb', style: TextStyle(fontSize: 11)),
                        onPressed: () => setQuickAmount(100000),
                      ),
                      ActionChip(
                        label: const Text('+500 rb', style: TextStyle(fontSize: 11)),
                        onPressed: () => setQuickAmount(50000),
                      ),
                      if (goal.remainingAmount > 0)
                        ActionChip(
                          label: const Text('Lunasi Target', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.teal.withValues(alpha: 0.15),
                          onPressed: () => setQuickAmount(goal.remainingAmount),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pilihan Akun Sumber
                  DropdownButtonFormField<int>(
                    initialValue: selectedAssetId,
                    decoration: InputDecoration(
                      labelText: 'Sumber Aset / Rekening',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      for (final a in assets)
                        DropdownMenuItem<int>(
                          value: a.id,
                          child: Text(a.name),
                        ),
                    ],
                    onChanged: (val) {
                      setState(() => selectedAssetId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Catat Transaksi Checkbox
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Catat di Arus Kas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      recordTx
                          ? 'Saldo aset akan dipotong & tercatat sebagai pengeluaran tabungan'
                          : 'Hanya alokasi virtual (saldo aset fisik tidak dipotong)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: recordTx,
                    onChanged: (val) => setState(() => recordTx = val),
                  ),
                  const SizedBox(height: 8),

                  // Catatan Opsional
                  TextFormField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      hintText: 'Misal: Tabungan gaji bulan ini',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Simpan'),
                onPressed: () async {
                  final amount = parseRibuan(amountCtrl.text);
                  if (amount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Masukkan nominal lebih dari 0')),
                    );
                    return;
                  }

                  await repo.allocateToGoal(
                    goalId: goal.id,
                    amount: amount,
                    assetId: selectedAssetId,
                    note: noteCtrl.text.trim(),
                    createTransaction: recordTx,
                    date: date,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Berhasil menabung ${rupiah(amount)} ke "${goal.title}"'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}

/// Dialog untuk Menarik Dana dari Target
Future<bool?> showTarikDanaDialog(BuildContext context, SavingsGoal goal) async {
  if (goal.currentAmount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Belum ada dana yang terkumpul untuk ditarik')),
    );
    return false;
  }

  final repo = context.read<Repo>();
  final assets = await repo.assets();
  if (!context.mounted) return false;

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  int? selectedAssetId = goal.assetId ?? (assets.isNotEmpty ? assets.first.id : null);
  bool recordTx = true;

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          void setQuickAmount(int val) {
            amountCtrl.text = formatRibuan(val);
            setState(() {});
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                  child: const Icon(Icons.output_rounded, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Tarik Dana Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        goal.title,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Nominal Penarikan',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Saldo tersedia: ${rupiah(goal.currentAmount)}',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Chips
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('25%', style: TextStyle(fontSize: 11)),
                        onPressed: () => setQuickAmount((goal.currentAmount * 0.25).round()),
                      ),
                      ActionChip(
                        label: const Text('50%', style: TextStyle(fontSize: 11)),
                        onPressed: () => setQuickAmount((goal.currentAmount * 0.50).round()),
                      ),
                      ActionChip(
                        label: const Text('Tarik Semua', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        onPressed: () => setQuickAmount(goal.currentAmount),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (assets.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      initialValue: selectedAssetId,
                      decoration: InputDecoration(
                        labelText: 'Kembalikan ke Akun Aset',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        for (final a in assets)
                          DropdownMenuItem<int>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                      ],
                      onChanged: (val) {
                        setState(() => selectedAssetId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tambah Saldo Aset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        recordTx
                            ? 'Saldo aset akan bertambah & tercatat sebagai pemasukan / refund'
                            : 'Hanya pengurangan saldo target virtual',
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: recordTx,
                      onChanged: (val) => setState(() => recordTx = val),
                    ),
                  ],
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Alasan / Catatan Penarikan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                onPressed: () async {
                  final amount = parseRibuan(amountCtrl.text);
                  if (amount <= 0 || amount > goal.currentAmount) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Nominal harus antara 1 sampai ${rupiah(goal.currentAmount)}')),
                    );
                    return;
                  }

                  await repo.withdrawFromGoal(
                    goalId: goal.id,
                    amount: amount,
                    assetId: selectedAssetId,
                    note: noteCtrl.text.trim(),
                    createTransaction: recordTx,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Berhasil menarik ${rupiah(amount)} dari "${goal.title}"'),
                        backgroundColor: Colors.orange.shade800,
                      ),
                    );
                  }
                },
                child: const Text('Tarik Dana'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Dialog untuk Memindahkan Saldo Antar-Target
Future<bool?> showPindahSaldoDialog(BuildContext context, SavingsGoal fromGoal) async {
  if (fromGoal.currentAmount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tidak ada saldo untuk dipindahkan')),
    );
    return false;
  }

  final repo = context.read<Repo>();
  final allGoals = await repo.savingsGoals();
  final otherGoals = allGoals.where((g) => g.id != fromGoal.id).toList();

  if (otherGoals.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada target lain untuk menerima saldo')),
      );
    }
    return false;
  }

  if (!context.mounted) return false;

  final amountCtrl = TextEditingController(text: formatRibuan(fromGoal.currentAmount));
  final noteCtrl = TextEditingController();
  int toGoalId = otherGoals.first.id;

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.teal),
                SizedBox(width: 10),
                Expanded(child: Text('Pindahkan Saldo Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pindahkan saldo dari "${fromGoal.title}" (Tersedia: ${rupiah(fromGoal.currentAmount)})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),

                  // Pilihan Target Tujuan
                  DropdownButtonFormField<int>(
                    initialValue: toGoalId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Pindah ke Target',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      for (final g in otherGoals)
                        DropdownMenuItem<int>(
                          value: g.id,
                          child: Text(
                            '${g.title} (${rupiah(g.currentAmount)} / ${rupiah(g.targetAmount)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => toGoalId = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Nominal Pindah
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Nominal Dipindahkan',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = parseRibuan(amountCtrl.text);
                  if (amount <= 0 || amount > fromGoal.currentAmount) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Nominal harus antara 1 sampai ${rupiah(fromGoal.currentAmount)}')),
                    );
                    return;
                  }

                  await repo.transferBetweenGoals(
                    fromGoalId: fromGoal.id,
                    toGoalId: toGoalId,
                    amount: amount,
                    note: noteCtrl.text.trim(),
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Berhasil memindahkan saldo ${rupiah(amount)}'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                },
                child: const Text('Pindahkan'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Dialog Opsi saat Batas Waktu / Deadline Habis atau Mengelola Status Target
Future<void> showDeadlineOptionsDialog(BuildContext context, SavingsGoal goal) async {
  final repo = context.read<Repo>();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(goal.color).withValues(alpha: 0.15),
                    child: Icon(Icons.timer_off_outlined, color: Color(goal.color)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilihan Target: ${goal.title}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Terkumpul ${rupiah(goal.currentAmount)} dari ${rupiah(goal.targetAmount)} (${goal.progressPercent}%)',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // Opsi 1: Perpanjang Batas Waktu
              ListTile(
                leading: const Icon(Icons.update, color: Colors.blue),
                title: const Text('Perpanjang Batas Waktu', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Atur tanggal deadline baru untuk melanjutkan menabung'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2050),
                    helpText: 'Pilih Batas Waktu Baru',
                  );
                  if (picked != null) {
                    await repo.extendGoalDeadline(goal.id, picked);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Batas waktu target diperpanjang ke ${tglPanjang(picked)}'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                  }
                },
              ),

              // Opsi 2: Tutup / Anggap Selesai dengan nominal yang ada
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.teal),
                title: const Text('Tutup / Selesai dengan Nominal Saat Ini', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Selesaikan target sekarang dengan dana terkumpul ${rupiah(goal.currentAmount)}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await repo.updateGoalStatus(goal.id, 'completed');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Target "${goal.title}" telah ditandai selesai.'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                },
              ),

              // Opsi 3: Pindahkan Sisa Saldo ke Target Lain
              if (goal.currentAmount > 0)
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.purple),
                  title: const Text('Pindahkan Saldo ke Target Lain', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Alihkan dana terkumpul ke target menabung impian lainnya'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showPindahSaldoDialog(context, goal);
                  },
                ),

              // Opsi 4: Tarik seluruh dana ke rekening
              if (goal.currentAmount > 0)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.orange),
                  title: const Text('Kembalikan Semua Saldo ke Akun Aset', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tarik seluruh saldo kembali ke rekening kas / bank Anda'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showTarikDanaDialog(context, goal);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

