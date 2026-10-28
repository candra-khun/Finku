import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/widget_service.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../transaksi/tx_form_page.dart';

class WidgetPreviewPage extends StatefulWidget {
  const WidgetPreviewPage({super.key});

  @override
  State<WidgetPreviewPage> createState() => _WidgetPreviewPageState();
}

class _WidgetPreviewPageState extends State<WidgetPreviewPage> {
  bool _hideBalance = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadHideBalance();
  }

  Future<void> _loadHideBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideBalance = prefs.getBool('widget_hide_balance') ?? false;
    });
  }

  Future<void> _toggleHideBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final updated = !_hideBalance;
    await prefs.setBool('widget_hide_balance', updated);
    setState(() {
      _hideBalance = updated;
    });
    if (mounted) {
      await WidgetService.updateWidgets(context.read<Repo>());
    }
  }

  Future<void> _manualSync() async {
    setState(() => _syncing = true);
    await WidgetService.updateWidgets(context.read<Repo>());
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data widget berhasil disinkronkan!'.tr),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D6B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text('Widget Layar Utama'.tr),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sinkronkan Widget'.tr,
            onPressed: _syncing ? null : _manualSync,
          ),
        ],
      ),
      body: FutureBuilder<(Totals, List<AssetGroup>, List<AssetBalance>, List<TxItem>)>(
        future: Future.wait([
          repo.totals(firstOfMonth(now), lastOfMonth(now)),
          repo.groups(),
          repo.assetBalances(),
          repo.recentTransactions(limit: 3),
        ]).then((res) => (
              res[0] as Totals,
              res[1] as List<AssetGroup>,
              res[2] as List<AssetBalance>,
              res[3] as List<TxItem>,
            )),
        builder: (context, snapshot) {
          final totals = snapshot.data?.$1 ?? const Totals(0, 0);
          final groups = snapshot.data?.$2 ?? <AssetGroup>[];
          final balances = snapshot.data?.$3 ?? <AssetBalance>[];
          final recentTxs = snapshot.data?.$4 ?? <TxItem>[];

          final monthLabel = periodLabel(periodOf(now));
          final netBalance = totals.income - totals.expense;
          final totalAsset = balances.fold<int>(0, (s, b) => s + b.balance);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2824) : const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF2E7D6B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.widgets_outlined, color: Color(0xFF2E7D6B), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tersedia di Layar Beranda HP'.tr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Catat transaksi tanpa buka aplikasi & pantau saldo langsung dari Home Screen.'
                                .tr,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Title Widget Kecil
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Widget kecil (2x2)'.tr,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _toggleHideBalance,
                    icon: Icon(
                      _hideBalance ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                    ),
                    label: Text(
                      _hideBalance ? 'Tampilkan Saldo'.tr : 'Sembunyikan Saldo'.tr,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Mockup Card 2x2
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: _buildSmallWidgetCard(
                    monthLabel: monthLabel,
                    netBalance: netBalance,
                    income: totals.income,
                    expense: totals.expense,
                    isHidden: _hideBalance,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title Widget Besar
              Text(
                'Widget besar (4x3)'.tr,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Mockup Card 4x3
              _buildLargeWidgetCard(
                totalAsset: totalAsset,
                groups: groups,
                balances: balances,
                recentTxs: recentTxs,
                isHidden: _hideBalance,
              ),

              const SizedBox(height: 32),

              // Panduan Pasang
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline, color: Color(0xFF2E7D6B), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Cara Memasang di HP Android'.tr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _stepItem(1, 'Buka Layar Beranda (Home Screen) HP Anda.'),
                      _stepItem(2, 'Tekan dan tahan (long-press) bagian layar yang kosong.'),
                      _stepItem(3, 'Ketuk menu "Widget" atau ikon plus (+) di layar.'),
                      _stepItem(4, 'Gulir ke bawah dan cari aplikasi "Finku".'),
                      _stepItem(5, 'Pilih "Widget Kecil (2x2)" atau "Widget Besar (4x3)", lalu geser ke layar Anda.'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _stepItem(int step, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D6B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$step',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D6B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              desc.tr,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallWidgetCard({
    required String monthLabel,
    required int netBalance,
    required int income,
    required int expense,
    required bool isHidden,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2D333D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Month & Eye
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthLabel,
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: _toggleHideBalance,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isHidden ? Icons.visibility_off : Icons.visibility_outlined,
                    color: const Color(0xFF9E9E9E),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Total
          const Text(
            'Total',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isHidden ? 'Rp ••••••••' : rupiah(netBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),

          // Income & Expense compact
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward, color: Color(0xFF29B6F6), size: 12),
                  const SizedBox(width: 3),
                  Text(
                    isHidden ? '••••' : ringkas(income),
                    style: const TextStyle(
                      color: Color(0xFF29B6F6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward, color: Color(0xFFFF5C5C), size: 12),
                  const SizedBox(width: 3),
                  Text(
                    isHidden ? '••••' : ringkas(expense),
                    style: const TextStyle(
                      color: Color(0xFFFF5C5C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Action Buttons
          Row(
            children: [
              // Tombol Keluar (Expense)
              Expanded(
                child: Material(
                  color: const Color(0xFF361717),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openTxForm(context, initialType: 'expense'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF5C2525)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward, color: Color(0xFFFF6B6B), size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Keluar',
                            style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Masuk (Income)
              Expanded(
                child: Material(
                  color: const Color(0xFF102538),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openTxForm(context, initialType: 'income'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF1C4566)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward, color: Color(0xFF38BDF8), size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Masuk',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeWidgetCard({
    required int totalAsset,
    required List<AssetGroup> groups,
    required List<AssetBalance> balances,
    required List<TxItem> recentTxs,
    required bool isHidden,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2D333D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Total Aset & Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total aset',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHidden ? 'Rp ••••••••••' : rupiah(totalAsset),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _toggleHideBalance,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isHidden ? Icons.visibility_off : Icons.visibility_outlined,
                    color: const Color(0xFF9E9E9E),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: const Color(0xFF133E60),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => openTxForm(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, color: Color(0xFF38BDF8), size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Kelompok Aset
          Row(
            children: List.generate(3, (index) {
              final groupName = index < groups.length ? groups[index].name : '-';
              final groupBal = index < groups.length
                  ? balances
                      .where((b) => b.asset.groupId == groups[index].id)
                      .fold<int>(0, (s, b) => s + b.balance)
                  : 0;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 5,
                    right: index == 2 ? 0 : 5,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF232832),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isHidden ? '••••' : ringkas(groupBal),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          const Divider(color: Color(0xFF282E3A), height: 1),
          const SizedBox(height: 14),

          // Section Transaksi Terbaru
          const Text(
            'Transaksi terbaru',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          if (recentTxs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Belum ada transaksi',
                  style: TextStyle(color: Color(0xFF757575), fontSize: 12),
                ),
              ),
            )
          else
            ...recentTxs.take(3).map((tx) {
              final cat = tx.categoryName ?? (tx.type == 'transfer' ? 'Transfer' : 'Lainnya');
              final isIncome = tx.type == 'income';
              final String sign;
              if (tx.type == 'income') {
                sign = '+';
              } else if (tx.type == 'expense') {
                sign = '-';
              } else {
                sign = '';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: cat,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ' · ${tx.assetName}',
                              style: const TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isHidden ? '••••••••' : '$sign${rupiah(tx.amount)}',
                      style: TextStyle(
                        color: isIncome ? const Color(0xFF29B6F6) : const Color(0xFFFF5C5C),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

