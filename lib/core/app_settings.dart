import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyModel {
  final String code;
  final String name;
  final String symbol;
  final bool isPrefix;
  final String thousandSep;
  final String decimalSep;
  final String flag;
  final bool isCustom;

  const CurrencyModel({
    required this.code,
    required this.name,
    required this.symbol,
    this.isPrefix = true,
    this.thousandSep = '.',
    this.decimalSep = ',',
    this.flag = '🌐',
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'symbol': symbol,
        'isPrefix': isPrefix,
        'thousandSep': thousandSep,
        'decimalSep': decimalSep,
        'flag': flag,
        'isCustom': isCustom,
      };

  factory CurrencyModel.fromMap(Map<String, dynamic> m) => CurrencyModel(
        code: m['code'] as String,
        name: m['name'] as String,
        symbol: m['symbol'] as String,
        isPrefix: (m['isPrefix'] as bool?) ?? true,
        thousandSep: (m['thousandSep'] as String?) ?? '.',
        decimalSep: (m['decimalSep'] as String?) ?? ',',
        flag: (m['flag'] as String?) ?? '🌐',
        isCustom: (m['isCustom'] as bool?) ?? false,
      );
}

class LanguageModel {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  static const _kLanguage = 'app_language';
  static const _kCurrencyCode = 'app_currency_code';
  static const _kCustomCurrencies = 'app_custom_currencies';

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Standar mata uang bawaan
  static const List<CurrencyModel> defaultCurrencies = [
    CurrencyModel(
      code: 'IDR',
      name: 'Rupiah Indonesia',
      symbol: 'Rp',
      isPrefix: true,
      thousandSep: '.',
      decimalSep: ',',
      flag: '🇮🇩',
    ),
    CurrencyModel(
      code: 'USD',
      name: 'US Dollar',
      symbol: '\$',
      isPrefix: true,
      thousandSep: ',',
      decimalSep: '.',
      flag: '🇺🇸',
    ),
    CurrencyModel(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      isPrefix: true,
      thousandSep: '.',
      decimalSep: ',',
      flag: '🇪🇺',
    ),
    CurrencyModel(
      code: 'SGD',
      name: 'Singapore Dollar',
      symbol: 'S\$',
      isPrefix: true,
      thousandSep: ',',
      decimalSep: '.',
      flag: '🇸🇬',
    ),
    CurrencyModel(
      code: 'MYR',
      name: 'Ringgit Malaysia',
      symbol: 'RM',
      isPrefix: true,
      thousandSep: ',',
      decimalSep: '.',
      flag: '🇲🇾',
    ),
    CurrencyModel(
      code: 'JPY',
      name: 'Japanese Yen',
      symbol: '¥',
      isPrefix: true,
      thousandSep: ',',
      decimalSep: '.',
      flag: '🇯🇵',
    ),
    CurrencyModel(
      code: 'GBP',
      name: 'British Pound',
      symbol: '£',
      isPrefix: true,
      thousandSep: ',',
      decimalSep: '.',
      flag: '🇬🇧',
    ),
    CurrencyModel(
      code: 'SAR',
      name: 'Saudi Riyal',
      symbol: 'ر.س',
      isPrefix: false,
      thousandSep: ',',
      decimalSep: '.',
      flag: '🇸🇦',
    ),
    CurrencyModel(
      code: 'AUD',
      name: 'Australian Dollar',
      symbol: 'A\$',
      isPrefix: true,
      thousandSep: ',',
      decimalSep: '.',
      flag: '🇦🇺',
    ),
  ];

  static const List<LanguageModel> supportedLanguages = [
    LanguageModel(
      code: 'id',
      name: 'Bahasa Indonesia',
      nativeName: 'Bahasa Indonesia',
      flag: '🇮🇩',
    ),
    LanguageModel(
      code: 'en',
      name: 'English',
      nativeName: 'English (US)',
      flag: '🇬🇧',
    ),
  ];

  String _languageCode = 'id';
  CurrencyModel _currency = defaultCurrencies.first;
  final List<CurrencyModel> _customCurrencies = [];

  bool get isInitialized => _initialized;
  String get languageCode => _languageCode;
  bool get isEnglish => _languageCode == 'en';
  bool get isIndonesian => _languageCode == 'id';
  CurrencyModel get currency => _currency;
  List<CurrencyModel> get allCurrencies => [...defaultCurrencies, ..._customCurrencies];

  LanguageModel get currentLanguage {
    return supportedLanguages.firstWhere(
      (l) => l.code == _languageCode,
      orElse: () => supportedLanguages.first,
    );
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _languageCode = _prefs?.getString(_kLanguage) ?? 'id';

      // Load custom currencies
      final customJson = _prefs?.getStringList(_kCustomCurrencies) ?? [];
      _customCurrencies.clear();
      for (final jsonStr in customJson) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          _customCurrencies.add(CurrencyModel.fromMap(map));
        } catch (_) {}
      }

      // Load active currency
      final savedCode = _prefs?.getString(_kCurrencyCode) ?? 'IDR';
      _currency = allCurrencies.firstWhere(
        (c) => c.code == savedCode,
        orElse: () => defaultCurrencies.first,
      );
    } catch (e) {
      debugPrint('AppSettings init error: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    await _prefs?.setString(_kLanguage, code);
    notifyListeners();
  }

  Future<void> setCurrency(CurrencyModel cur) async {
    _currency = cur;
    await _prefs?.setString(_kCurrencyCode, cur.code);
    notifyListeners();
  }

  Future<void> addCustomCurrency(CurrencyModel model) async {
    _customCurrencies.removeWhere((c) => c.code == model.code);
    _customCurrencies.add(model);
    final jsonList = _customCurrencies.map((c) => jsonEncode(c.toMap())).toList();
    await _prefs?.setStringList(_kCustomCurrencies, jsonList);
    await setCurrency(model);
  }

  Future<void> deleteCustomCurrency(String code) async {
    _customCurrencies.removeWhere((c) => c.code == code);
    final jsonList = _customCurrencies.map((c) => jsonEncode(c.toMap())).toList();
    await _prefs?.setStringList(_kCustomCurrencies, jsonList);
    if (_currency.code == code) {
      await setCurrency(defaultCurrencies.first);
    } else {
      notifyListeners();
    }
  }

  /// Format angka integer sesuai pemisah ribuan mata uang yang aktif
  String formatNumber(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    final sep = _currency.thousandSep;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(sep);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Format uang lengkap (simbol + pemisah ribuan)
  String formatMoney(int value) {
    final negative = value < 0;
    final formattedDigits = formatNumber(value);
    final sym = _currency.symbol;

    if (_currency.isPrefix) {
      return '${negative ? '-' : ''}$sym $formattedDigits';
    } else {
      return '${negative ? '-' : ''}$formattedDigits $sym';
    }
  }

  /// Format ringkas (misal: 1,5jt atau 1.5M)
  String formatCompact(int value) {
    final isEn = _languageCode == 'en';
    final sep = _currency.decimalSep;

    if (value >= 1000000000) {
      final v = value / 1000000000;
      final s = v.toStringAsFixed(1).replaceAll('.', sep);
      final clean = s.endsWith('${sep}0') ? s.substring(0, s.length - 2) : s;
      return '$clean${isEn ? 'B' : 'M'}';
    }
    if (value >= 1000000) {
      final v = value / 1000000;
      final s = v.toStringAsFixed(1).replaceAll('.', sep);
      final clean = s.endsWith('${sep}0') ? s.substring(0, s.length - 2) : s;
      return '$clean${isEn ? 'M' : 'jt'}';
    }
    if (value >= 1000) {
      return '${value ~/ 1000}${isEn ? 'K' : 'rb'}';
    }
    return value.toString();
  }
}

