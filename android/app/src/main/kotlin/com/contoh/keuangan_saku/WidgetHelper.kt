package com.contoh.keuangan_saku

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

object WidgetHelper {
    const val PREFS_NAME = "FlutterSharedPreferences"
    const val KEY_PREFIX = "flutter."
    const val KEY_HIDE_BALANCE = "${KEY_PREFIX}widget_hide_balance"

    const val ACTION_TOGGLE_HIDE = "com.contoh.keuangan_saku.ACTION_TOGGLE_HIDE"
    const val ACTION_QUICK_ADD_EXPENSE = "com.contoh.keuangan_saku.ACTION_QUICK_ADD_EXPENSE"
    const val ACTION_QUICK_ADD_INCOME = "com.contoh.keuangan_saku.ACTION_QUICK_ADD_INCOME"
    const val ACTION_QUICK_ADD = "com.contoh.keuangan_saku.ACTION_QUICK_ADD"

    private var lastToggleTime = 0L

    fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun isBalanceHidden(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_HIDE_BALANCE, false)
    }

    @Synchronized
    fun toggleBalanceHidden(context: Context): Boolean {
        val now = System.currentTimeMillis()
        // Cegah eksekusi ganda jika dipanggil berdekatan oleh multiple receivers
        if (now - lastToggleTime < 400L) {
            return isBalanceHidden(context)
        }
        lastToggleTime = now

        val prefs = getPrefs(context)
        val current = prefs.getBoolean(KEY_HIDE_BALANCE, false)
        val updated = !current
        prefs.edit().putBoolean(KEY_HIDE_BALANCE, updated).apply()
        updateAllWidgets(context)
        return updated
    }

    fun updateAllWidgets(context: Context) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)

            // Update Small Widgets
            val smallComponent = ComponentName(context, SmallWidgetProvider::class.java)
            val smallIds = appWidgetManager.getAppWidgetIds(smallComponent)
            if (smallIds.isNotEmpty()) {
                for (id in smallIds) {
                    try {
                        SmallWidgetProvider.updateAppWidget(context, appWidgetManager, id)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                val intent = Intent(context, SmallWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, smallIds)
                }
                context.sendBroadcast(intent)
            }

            // Update Large Widgets
            val largeComponent = ComponentName(context, LargeWidgetProvider::class.java)
            val largeIds = appWidgetManager.getAppWidgetIds(largeComponent)
            if (largeIds.isNotEmpty()) {
                for (id in largeIds) {
                    try {
                        LargeWidgetProvider.updateAppWidget(context, appWidgetManager, id)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                val intent = Intent(context, LargeWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, largeIds)
                }
                context.sendBroadcast(intent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun getOpenAppPendingIntent(context: Context, actionType: String? = null, requestCode: Int = 0): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (actionType != null) {
                action = actionType
            }
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }

    fun getToggleHidePendingIntent(context: Context, targetClass: Class<*>, requestCode: Int = 100): PendingIntent {
        // Menggunakan Explicit Intent langsung ke kelas target receiver
        val intent = Intent(context, targetClass).apply {
            action = ACTION_TOGGLE_HIDE
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    fun formatMasked(actual: String, isHidden: Boolean): String {
        return if (isHidden) "Rp ••••••" else actual
    }

    fun formatMaskedCompact(actual: String, isHidden: Boolean): String {
        return if (isHidden) "••••" else actual
    }
}
