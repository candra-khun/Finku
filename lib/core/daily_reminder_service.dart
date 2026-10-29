import 'package:flutter/services.dart';

class DailyReminderService {
  DailyReminderService._();

  static const _channel =
      MethodChannel('com.contoh.keuangan_saku/daily_reminder');

  /// Menjadwalkan pengingat Android setiap hari pukul 20.00 WIB.
  static Future<void> schedule() async {
    try {
      await _channel.invokeMethod<void>('scheduleDailyReminder');
    } on PlatformException {
      // Pengingat bersifat tambahan; aplikasi tetap dapat digunakan bila
      // perangkat menolak izin notifikasi atau penjadwalan alarm.
    }
  }
}
