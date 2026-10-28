package com.contoh.keuangan_saku

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class SmallWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetHelper.ACTION_TOGGLE_HIDE) {
            WidgetHelper.toggleBalanceHidden(context)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = WidgetHelper.getPrefs(context)
            val isHidden = WidgetHelper.isBalanceHidden(context)

            val monthLabel = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_month_label", "Bulan Ini") ?: "Bulan Ini"
            val totalAmount = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_month_total", "Rp 0") ?: "Rp 0"
            val incomeCompact = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_month_income", "0") ?: "0"
            val expenseCompact = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_month_expense", "0") ?: "0"

            val views = RemoteViews(context.packageName, R.layout.widget_small)

            views.setTextViewText(R.id.tv_small_month, monthLabel)
            views.setTextViewText(R.id.tv_small_total_amount, WidgetHelper.formatMasked(totalAmount, isHidden))
            views.setTextViewText(R.id.tv_small_income, WidgetHelper.formatMaskedCompact(incomeCompact, isHidden))
            views.setTextViewText(R.id.tv_small_expense, WidgetHelper.formatMaskedCompact(expenseCompact, isHidden))

            // Ikon mata
            val eyeRes = if (isHidden) R.drawable.ic_widget_eye_off else R.drawable.ic_widget_eye
            views.setImageViewResource(R.id.btn_small_toggle_eye, eyeRes)

            // Klik ikon mata
            val toggleIntent = WidgetHelper.getToggleHidePendingIntent(context, appWidgetId)
            views.setOnClickPendingIntent(R.id.btn_small_toggle_eye, toggleIntent)

            // Klik cepat tombol Keluar
            val expenseIntent = WidgetHelper.getOpenAppPendingIntent(context, WidgetHelper.ACTION_QUICK_ADD_EXPENSE, 201)
            views.setOnClickPendingIntent(R.id.btn_small_expense, expenseIntent)

            // Klik cepat tombol Masuk
            val incomeIntent = WidgetHelper.getOpenAppPendingIntent(context, WidgetHelper.ACTION_QUICK_ADD_INCOME, 202)
            views.setOnClickPendingIntent(R.id.btn_small_income, incomeIntent)

            // Klik bodi widget membuka aplikasi
            val openAppIntent = WidgetHelper.getOpenAppPendingIntent(context, null, 200)
            views.setOnClickPendingIntent(R.id.widget_small_root, openAppIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

