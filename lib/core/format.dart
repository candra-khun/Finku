import 'package:flutter/services.dart';

import 'app_settings.dart';

const Color incomeColor = Color(0xFF1E88E5);
const Color expenseColor = Color(0xFFE53935);
const Color transferColor = Color(0xFF757575);

const List<String> bulanId = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const List<String> bulanEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> bulanPendekId = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const List<String> bulanPendekEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> hariId = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const List<String> hariEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

List<String> get bulan => AppSettings.instance.isEnglish ? bulanEn : bulanId;
List<String> get bulanPendek =>
    AppSettings.instance.isEnglish ? bulanPendekEn : bulanPendekId;
List<String> get hari => AppSettings.instance.isEnglish ? hariEn : hariId;

/// Format Uang / Mata Uang (sebelumnya rupiah): 1500000 -> "Rp 1.500.000", -2500 -> "-Rp 2.500".
String rupiah(int value) => AppSettings.instance.formatMoney(value);

/// Format ringkas untuk sel kalender: 1500000 -> "1,5jt", 25000 -> "25rb".
String ringkas(int value) => AppSettings.instance.formatCompact(value);

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Periode "2026-10" dari sebuah tanggal.
String periodOf(DateTime d) => ymd(d).substring(0, 7);

/// "2026-10" -> "Oktober 2026".
String periodLabel(String period) {
  final p = period.split('-');
  return '${bulan[int.parse(p[1]) - 1]} ${p[0]}';
}

String tglPanjang(DateTime d) => '${d.day} ${bulan[d.month - 1]} ${d.year}';

String tglPendek(DateTime d) => '${d.day} ${bulanPendek[d.month - 1]} ${d.year}';

String namaHari(DateTime d) => hari[d.weekday - 1];

DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime lastOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

/// Format angka dengan pemisah ribuan dinamis sesuai mata uang aktif (1500000 -> "1.500.000").
String formatRibuan(int value) => AppSettings.instance.formatNumber(value);

/// Parse string berpemisah titik kembali ke integer ("1.500.000" -> 1500000).
int parseRibuan(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return int.tryParse(digits) ?? 0;
}

/// Formatter input teks yang otomatis menyisipkan titik ribuan saat mengetik.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final cleanDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final number = int.tryParse(cleanDigits);
    if (number == null) {
      return oldValue;
    }

    final formatted = formatRibuan(number);

    // Hitung posisi kursor berdasarkan jumlah digit sebelum kursor
    final cursorPositionInDigits = newValue.selection.baseOffset < 0
        ? cleanDigits.length
        : newValue.text
            .substring(0, newValue.selection.baseOffset)
            .replaceAll(RegExp(r'\D'), '')
            .length;

    var digitCount = 0;
    var newCursorIndex = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitCount++;
      }
      if (digitCount == cursorPositionInDigits) {
        newCursorIndex = i + 1;
        break;
      }
    }

    if (cursorPositionInDigits == 0) {
      newCursorIndex = 0;
    } else if (newCursorIndex == 0) {
      newCursorIndex = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorIndex),
    );
  }
}
