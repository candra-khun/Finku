import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository.dart';
import 'format.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.contoh.keuangan_saku/widget');

  /// Memperbarui data untuk Home Screen Widget (2x2 dan 4x3) dan memberi tahu native widget.
  static Future<void> updateWidgets(Repo repo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // 1. Data Ringkasan Bulan Ini (Widget Kecil & Besar)
      final monthTotals = await repo.totals(firstOfMonth(now), lastOfMonth(now));
      final monthLabel = periodLabel(periodOf(now));
      final netBalance = monthTotals.income - monthTotals.expense;

      await prefs.setString('widget_month_label', monthLabel);
      await prefs.setString('widget_month_total', rupiah(netBalance));
      await prefs.setString('widget_month_income', ringkas(monthTotals.income));
      await prefs.setString('widget_month_expense', ringkas(monthTotals.expense));

      // 2. Data Saldo Aset (Widget Besar)
      final groups = await repo.groups();
      final balances = await repo.assetBalances();

      final totalAsset = balances.fold<int>(0, (sum, b) => sum + b.balance);
      await prefs.setString('widget_total_asset', rupiah(totalAsset));

      // Ambil hingga 3 grup aset (default atau teratas)
      for (var i = 0; i < 3; i++) {
        final keyNum = i + 1;
        if (i < groups.length) {
          final group = groups[i];
          final groupBal = balances
              .where((b) => b.asset.groupId == group.id)
              .fold<int>(0, (sum, b) => sum + b.balance);
          await prefs.setString('widget_group${keyNum}_name', group.name);
          await prefs.setString('widget_group${keyNum}_val', ringkas(groupBal));
        } else {
          await prefs.setString('widget_group${keyNum}_name', '-');
          await prefs.setString('widget_group${keyNum}_val', '0');
        }
      }

      // 3. Data 3 Transaksi Terbaru (Widget Besar)
      final recent = await repo.recentTransactions(limit: 3);
      for (var i = 0; i < 3; i++) {
        final keyNum = i + 1;
        if (i < recent.length) {
          final tx = recent[i];
          final cat = tx.categoryName ?? (tx.type == 'transfer' ? 'Transfer' : 'Lainnya');
          final title = '$cat · ${tx.assetName}';
          final String formattedAmount;
          if (tx.type == 'income') {
            formattedAmount = '+${rupiah(tx.amount)}';
          } else if (tx.type == 'expense') {
            formattedAmount = '-${rupiah(tx.amount)}';
          } else {
            formattedAmount = rupiah(tx.amount);
          }

          await prefs.setString('widget_tx${keyNum}_title', title);
          await prefs.setString('widget_tx${keyNum}_amount', formattedAmount);
          await prefs.setBool('widget_tx${keyNum}_is_income', tx.type == 'income');
        } else {
          await prefs.remove('widget_tx${keyNum}_title');
          await prefs.remove('widget_tx${keyNum}_amount');
          await prefs.remove('widget_tx${keyNum}_is_income');
        }
      }

      // Panggil native update
      await _channel.invokeMethod('updateWidgets');
    } catch (e) {
      // Jangan ganggu alur utama jika gagal memanggil channel (misal saat running unit test)
    }
  }
}

