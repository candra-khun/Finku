package com.contoh.keuangan_saku

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        schedule(context)

        if (!hasTransactionToday(context)) {
            showNotification(context)
        }
    }

    private fun hasTransactionToday(context: Context): Boolean {
        val databaseFile = context.getDatabasePath("keuangan_saku.db")
        if (!databaseFile.exists()) return false

        return try {
            SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery(
                    "SELECT COUNT(*) FROM transactions WHERE date = ?",
                    arrayOf(todayWib()),
                ).use { cursor ->
                    cursor.moveToFirst() && cursor.getInt(0) > 0
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun showNotification(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Pengingat catatan keuangan",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Pengingat harian untuk mencatat transaksi"
                },
            )
        }

        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Belum mencatat transaksi hari ini")
            .setContentText("Catat pemasukan atau pengeluaran Anda agar keuangan tetap terpantau.")
            .setStyle(
                android.app.Notification.BigTextStyle().bigText(
                    "Catat pemasukan atau pengeluaran Anda agar keuangan tetap terpantau.",
                ),
            )
            .setContentIntent(openAppPendingIntent)
            .setAutoCancel(true)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val CHANNEL_ID = "daily_transaction_reminder"
        private const val NOTIFICATION_ID = 2001
        private const val REQUEST_CODE = 2001
        private const val ACTION_REMINDER = "com.contoh.keuangan_saku.DAILY_REMINDER"
        private val wibTimeZone = TimeZone.getTimeZone("Asia/Jakarta")

        fun schedule(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val alarmIntent = Intent(context, DailyReminderReceiver::class.java).apply {
                action = ACTION_REMINDER
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val nextReminder = Calendar.getInstance(wibTimeZone).apply {
                set(Calendar.HOUR_OF_DAY, 20)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (!time.after(Calendar.getInstance(wibTimeZone).time)) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        nextReminder.timeInMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        nextReminder.timeInMillis,
                        pendingIntent,
                    )
                }
            } catch (_: SecurityException) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        nextReminder.timeInMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        nextReminder.timeInMillis,
                        pendingIntent,
                    )
                }
            }
        }

        private fun todayWib(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = wibTimeZone
        }.format(Calendar.getInstance(wibTimeZone).time)
    }
}

class DailyReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        DailyReminderReceiver.schedule(context)
    }
}
