import 'package:flutter_test/flutter_test.dart';
import 'package:keuangan_saku/core/app_settings.dart';
import 'package:keuangan_saku/core/format.dart';
import 'package:keuangan_saku/core/localization.dart';
import 'package:keuangan_saku/data/models.dart';

void main() {
  test('rupiah memakai titik pemisah ribuan', () {
    expect(rupiah(0), 'Rp 0');
    expect(rupiah(1500000), 'Rp 1.500.000');
    expect(rupiah(-2500), '-Rp 2.500');
    expect(formatRibuan(2000000), '2.000.000');
    expect(parseRibuan('2.000.000'), 2000000);
  });

  test('ringkas untuk sel kalender', () {
    expect(ringkas(500), '500');
    expect(ringkas(25000), '25rb');
    expect(ringkas(1500000), '1,5jt');
    expect(ringkas(2000000), '2jt');
  });

  test('periode dan tanggal', () {
    expect(ymd(DateTime(2026, 10, 7)), '2026-10-07');
    expect(periodOf(DateTime(2026, 10, 27)), '2026-10');
    expect(periodLabel('2026-10'), 'Oktober 2026');
    expect(parseYmd('2026-10-27'), DateTime(2026, 10, 27));
  });

  test('perhitungan anggaran per kategori', () {
    const cat = Category(id: 1, name: 'Makanan', type: 'expense', color: 0xFF00FF00);
    const bNormal = CategoryBudget(
      category: cat,
      budgetAmount: 2000000,
      spentAmount: 1500000,
      period: '2026-10',
    );
    expect(bNormal.remaining, 500000);
    expect(bNormal.isOverBudget, false);
    expect(bNormal.progress, 0.75);

    const bOver = CategoryBudget(
      category: cat,
      budgetAmount: 2000000,
      spentAmount: 2500000,
      period: '2026-10',
    );
    expect(bOver.remaining, -500000);
    expect(bOver.isOverBudget, true);
    expect(bOver.progress, 1.25);
  });

  test('perhitungan tanggal jatuh tempo transaksi berulang', () {
    final start = DateTime(2026, 10, 15);
    final nextMonth = computeNextDueDate(start, 'monthly', 1, 15);
    expect(nextMonth, DateTime(2026, 11, 15));

    final nextYear = computeNextDueDate(start, 'yearly', 1, 15);
    expect(nextYear, DateTime(2027, 10, 15));

    final nextWeek = computeNextDueDate(start, 'weekly', 1, 15);
    expect(nextWeek, DateTime(2026, 10, 22));

    // Handle akhir bulan (misal tgl 31 pada bulan 30 hari)
    final jan31 = DateTime(2026, 1, 31);
    final feb = computeNextDueDate(jan31, 'monthly', 1, 31);
    expect(feb, DateTime(2026, 2, 28)); // 2026 bukan tahun kabisat
  });

  test('perhitungan modul target menabung (savings goals)', () {
    final now = DateTime.now();
    final deadlineFuture = now.add(const Duration(days: 10));
    final goal = SavingsGoal(
      id: 1,
      title: 'Beli Laptop',
      targetAmount: 2000000,
      currentAmount: 1900000,
      targetDate: deadlineFuture,
      color: 0xFF00897B,
      icon: 'laptop',
      status: 'active',
      note: 'Cicil dari gaji bulanan',
      createdAt: now,
    );

    expect(goal.remainingAmount, 100000);
    expect(goal.progress, 0.95);
    expect(goal.progressPercent, 95);
    expect(goal.isCompleted, false);
    expect(goal.isOverdue, false);
    expect(goal.hasDeadline, true);
    expect(goal.daysRemaining, 10);

    // Kasus target selesai 100%
    final goalDone = SavingsGoal(
      id: 2,
      title: 'Beli HP',
      targetAmount: 2000000,
      currentAmount: 2000000,
      color: 0xFF00897B,
      icon: 'phone',
      status: 'completed',
      note: '',
      createdAt: now,
    );
    expect(goalDone.remainingAmount, 0);
    expect(goalDone.progress, 1.0);
    expect(goalDone.progressPercent, 100);
    expect(goalDone.isCompleted, true);

    // Kasus deadline lewat dan belum 100%
    final deadlinePast = now.subtract(const Duration(days: 3));
    final goalOverdue = SavingsGoal(
      id: 3,
      title: 'Target Bulan Ini',
      targetAmount: 2000000,
      currentAmount: 1900000,
      targetDate: deadlinePast,
      color: 0xFF00897B,
      icon: 'flag',
      status: 'active',
      note: '',
      createdAt: now.subtract(const Duration(days: 30)),
    );
    expect(goalOverdue.isOverdue, true);
    expect(goalOverdue.isCompleted, false);
    expect(goalOverdue.progressPercent, 95);
    expect(goalOverdue.daysRemaining! < 0, true);
  });

  test('master bahasa dan format mata uang rupiah', () async {
    final settings = AppSettings.instance;
    // Default currency IDR (Rupiah Indonesia)
    expect(settings.currency.code, 'IDR');
    expect(settings.formatMoney(1500000), 'Rp 1.500.000');
    expect(settings.formatMoney(-2500), '-Rp 2.500');

    // Test ganti bahasa & lokalisasi
    await settings.setLanguage('id');
    expect('Transaksi'.tr, 'Transaksi');
    expect('Pengeluaran'.tr, 'Pengeluaran');
    expect(periodLabel('2026-10'), 'Oktober 2026');
    expect(namaHari(DateTime(2026, 10, 27)), 'Selasa');

    await settings.setLanguage('en');
    expect('Transaksi'.tr, 'Transactions');
    expect('Pengeluaran'.tr, 'Expense');
    expect(periodLabel('2026-10'), 'October 2026');
    expect(namaHari(DateTime(2026, 10, 27)), 'Tuesday');

    // Kembalikan ke id
    await settings.setLanguage('id');
  });

  test('format data dan teks lokalisasi widget layar utama', () {
    // Verifikasi teks widget di kedua bahasa
    expect('Widget Layar Utama'.tr, 'Widget Layar Utama');
    expect('Widget kecil (2x2)'.tr, 'Widget kecil (2x2)');
    expect('Widget besar (4x3)'.tr, 'Widget besar (4x3)');

    AppSettings.instance.setLanguage('en');
    expect('Widget Layar Utama'.tr, 'Home Screen Widgets');
    expect('Widget kecil (2x2)'.tr, 'Small Widget (2x2)');
    expect('Widget besar (4x3)'.tr, 'Large Widget (4x3)');

    AppSettings.instance.setLanguage('id');

    // Verifikasi format ringkas untuk widget
    expect(ringkas(8500000), '8,5jt');
    expect(ringkas(5250000), '5,25jt');
    expect(ringkas(1200000), '1,2jt');
    expect(ringkas(1180000), '1,18jt');
    expect(rupiah(3250000), 'Rp 3.250.000');
    expect(rupiah(12480000), 'Rp 12.480.000');
  });
}
