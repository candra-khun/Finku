package com.contoh.keuangan_saku

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews

class LargeWidgetProvider : AppWidgetProvider() {

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
            try {
                val prefs = WidgetHelper.getPrefs(context)
                val isHidden = WidgetHelper.isBalanceHidden(context)

                val totalAsset = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_total_asset", "Rp 0") ?: "Rp 0"

                val views = RemoteViews(context.packageName, R.layout.widget_large)

                // Header Total Aset
                views.setTextViewText(R.id.tv_large_total_asset, WidgetHelper.formatMasked(totalAsset, isHidden))

                // Ikon Mata
                val eyeRes = if (isHidden) R.drawable.ic_widget_eye_off else R.drawable.ic_widget_eye
                views.setImageViewResource(R.id.btn_large_toggle_eye, eyeRes)

                // Tombol Mata
                val toggleIntent = WidgetHelper.getToggleHidePendingIntent(context, LargeWidgetProvider::class.java, appWidgetId + 500)
                views.setOnClickPendingIntent(R.id.btn_large_toggle_eye, toggleIntent)

                // Tombol Tambah Cepat (+)
                val addIntent = WidgetHelper.getOpenAppPendingIntent(context, WidgetHelper.ACTION_QUICK_ADD, 301)
                views.setOnClickPendingIntent(R.id.btn_large_quick_add, addIntent)

                // 3 Kelompok Aset
                val g1Name = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_group1_name", "Tunai") ?: "Tunai"
                val g1Val = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_group1_val", "0") ?: "0"
                val g2Name = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_group2_name", "Bank") ?: "Bank"
                val g2Val = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_group2_val", "0") ?: "0"
                val g3Name = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_group3_name", "Kartu") ?: "Kartu"
                val g3Val = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_group3_val", "0") ?: "0"

                views.setTextViewText(R.id.tv_large_group1_name, g1Name)
                views.setTextViewText(R.id.tv_large_group1_val, WidgetHelper.formatMaskedCompact(g1Val, isHidden))

                views.setTextViewText(R.id.tv_large_group2_name, g2Name)
                views.setTextViewText(R.id.tv_large_group2_val, WidgetHelper.formatMaskedCompact(g2Val, isHidden))

                views.setTextViewText(R.id.tv_large_group3_name, g3Name)
                views.setTextViewText(R.id.tv_large_group3_val, WidgetHelper.formatMaskedCompact(g3Val, isHidden))

                // 3 Transaksi Terbaru
                bindTransactionRow(views, prefs, isHidden, 1, R.id.row_tx_1, R.id.tv_large_tx1_title, R.id.tv_large_tx1_amount)
                bindTransactionRow(views, prefs, isHidden, 2, R.id.row_tx_2, R.id.tv_large_tx2_title, R.id.tv_large_tx2_amount)
                bindTransactionRow(views, prefs, isHidden, 3, R.id.row_tx_3, R.id.tv_large_tx3_title, R.id.tv_large_tx3_amount)

                // Klik bodi membuka aplikasi
                val openAppIntent = WidgetHelper.getOpenAppPendingIntent(context, null, 300)
                views.setOnClickPendingIntent(R.id.widget_large_root, openAppIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        private fun bindTransactionRow(
            views: RemoteViews,
            prefs: android.content.SharedPreferences,
            isHidden: Boolean,
            index: Int,
            rowId: Int,
            titleId: Int,
            amountId: Int
        ) {
            val title = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_tx${index}_title", null)
            val amount = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_tx${index}_amount", null)
            val isIncome = prefs.getBoolean("${WidgetHelper.KEY_PREFIX}widget_tx${index}_is_income", false)

            if (title.isNullOrEmpty() || amount.isNullOrEmpty()) {
                views.setViewVisibility(rowId, View.GONE)
            } else {
                views.setViewVisibility(rowId, View.VISIBLE)
                views.setTextViewText(titleId, title)
                views.setTextViewText(amountId, WidgetHelper.formatMasked(amount, isHidden))
                views.setTextColor(amountId, if (isIncome) Color.parseColor("#29B6F6") else Color.parseColor("#FF5C5C"))
            }
        }
    }
}
