import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService extends ChangeNotifier {
  static final SecurityService instance = SecurityService._();
  SecurityService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  late SharedPreferences _prefs;

  bool _initialized = false;
  bool _isLocked = false;
  bool _hasBiometrics = false;
  bool _isAuthenticating = false;
  DateTime? _pausedAt;
  DateTime? _unlockedAt;

  // Keys
  static const _kEnabled = 'sec_lock_enabled';
  static const _kPinHash = 'sec_pin_hash';
  static const _kPinSalt = 'sec_pin_salt';
  static const _kBiometricEnabled = 'sec_biometric_enabled';
  static const _kTimeoutSeconds = 'sec_timeout_seconds';

  bool get isInitialized => _initialized;
  bool get isLockEnabled => _prefs.getBool(_kEnabled) ?? false;
  bool get isBiometricEnabled => _prefs.getBool(_kBiometricEnabled) ?? true;
  int get timeoutSeconds => _prefs.getInt(_kTimeoutSeconds) ?? 0;
  bool get isLocked => _isLocked;
  bool get hasBiometrics => _hasBiometrics;
  bool get isAuthenticating => _isAuthenticating;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    // Cek ketersediaan perangkat biometrik
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      _hasBiometrics = canCheck && isSupported;
    } catch (e) {
      debugPrint('Biometrics check error: $e');
      _hasBiometrics = false;
    }

    if (isLockEnabled) {
      _isLocked = true;
    } else {
      _isLocked = false;
    }

    _initialized = true;
    notifyListeners();
  }

  // Hash PIN dengan salt SHA-256
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  String _generateSalt() {
    final rnd = Random.secure();
    final values = List<int>.generate(16, (i) => rnd.nextInt(256));
    return base64Url.encode(values);
  }

  /// Memverifikasi PIN pengguna
  bool verifyPin(String pin) {
    if (!isLockEnabled) return true;
    final storedHash = _prefs.getString(_kPinHash);
    final salt = _prefs.getString(_kPinSalt);
    if (storedHash == null || salt == null) return false;

    final computed = _hashPin(pin, salt);
    return computed == storedHash;
  }

  /// Mengatur PIN baru dan mengaktifkan kunci aplikasi
  Future<void> setupPin(String pin, {bool enableBiometric = true}) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _prefs.setString(_kPinSalt, salt);
    await _prefs.setString(_kPinHash, hash);
    await _prefs.setBool(_kEnabled, true);
    await _prefs.setBool(_kBiometricEnabled, enableBiometric && _hasBiometrics);

    _isLocked = false;
    notifyListeners();
  }

  /// Memperbarui PIN (setelah PIN lama diverifikasi)
  Future<void> changePin(String newPin) async {
    final salt = _generateSalt();
    final hash = _hashPin(newPin, salt);
    await _prefs.setString(_kPinSalt, salt);
    await _prefs.setString(_kPinHash, hash);
    notifyListeners();
  }

  /// Menonaktifkan kunci aplikasi
  Future<void> disableLock() async {
    await _prefs.setBool(_kEnabled, false);
    await _prefs.remove(_kPinHash);
    await _prefs.remove(_kPinSalt);
    _isLocked = false;
    notifyListeners();
  }

  /// Mengubah preferensi penggunaan biometrik
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_kBiometricEnabled, enabled);
    notifyListeners();
  }

  /// Mengubah batas waktu kunci otomatis (0 = langsung, 60 = 1 menit, 300 = 5 menit)
  Future<void> setTimeoutSeconds(int seconds) async {
    await _prefs.setInt(_kTimeoutSeconds, seconds);
    notifyListeners();
  }

  /// Autentikasi dengan biometrik (sidik jari / Face ID)
  Future<bool> authenticateBiometrics() async {
    if (!isLockEnabled || !isBiometricEnabled || !_hasBiometrics || _isAuthenticating) {
      return false;
    }

    _isAuthenticating = true;
    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari Anda untuk membuka Finku',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (success) {
        unlock();
        return true;
      }
    } catch (e) {
      debugPrint('Biometrics auth error: $e');
    } finally {
      // Tunggu jeda agar event lifecycle Android dari penutupan dialog selesai diproses
      await Future.delayed(const Duration(milliseconds: 500));
      _isAuthenticating = false;
    }
    return false;
  }

  /// Buka kunci aplikasi
  void unlock() {
    _isLocked = false;
    _pausedAt = null;
    _unlockedAt = DateTime.now();
    notifyListeners();
  }

  /// Kunci aplikasi secara manual
  void lock() {
    if (isLockEnabled && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// Dipanggil saat aplikasi masuk ke background
  void onAppPaused() {
    // Jangan catat waktu jeda jika sedang dalam proses dialog autentikasi biometrik
    if (_isAuthenticating) return;
    if (isLockEnabled) {
      _pausedAt ??= DateTime.now();
    }
  }

  /// Dipanggil saat aplikasi kembali aktif (resumed)
  void onAppResumed() {
    if (!isLockEnabled) return;
    if (_isLocked) return;

    // Abaikan jika sedang dalam dialog autentikasi biometrik
    if (_isAuthenticating) return;

    // Grace period: jika baru saja dibuka dalam 2 detik terakhir, jangan langsung kunci ulang
    if (_unlockedAt != null && DateTime.now().difference(_unlockedAt!).inSeconds < 2) {
      _pausedAt = null;
      return;
    }

    if (_pausedAt == null) {
      // Jika _pausedAt tidak tercatat namun aplikasi dibuka kembali,
      // kunci jika aturan timeout adalah langsung saat keluar (0 detik)
      if (timeoutSeconds == 0) {
        _isLocked = true;
        notifyListeners();
      }
      return;
    }

    final diff = DateTime.now().difference(_pausedAt!).inSeconds;
    if (diff >= timeoutSeconds) {
      _isLocked = true;
      notifyListeners();
    }
    _pausedAt = null;
  }
}
