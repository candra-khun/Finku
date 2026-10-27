import 'package:flutter_test/flutter_test.dart';
import 'package:keuangan_saku/core/format.dart';
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
}
