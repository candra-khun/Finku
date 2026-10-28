package com.contoh.keuangan_saku

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.widget.RemoteViews
import kotlin.math.max

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

                // Tren bulanan Jan–Des, sama seperti menu Statistik.
                bindMonthlyTrend(views, prefs, isHidden)

                // Klik bodi membuka aplikasi
                val openAppIntent = WidgetHelper.getOpenAppPendingIntent(context, null, 300)
                views.setOnClickPendingIntent(R.id.widget_large_root, openAppIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        private fun bindMonthlyTrend(
            views: RemoteViews,
            prefs: android.content.SharedPreferences,
            isHidden: Boolean
        ) {
            val labels = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_trend_months", "")
                ?.split('|')
                ?.filter { it.isNotBlank() }
                .orEmpty()
            val income = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_trend_income", "")
                ?.split('|')
                ?.map { it.toLongOrNull() ?: 0L }
                .orEmpty()
            val expense = prefs.getString("${WidgetHelper.KEY_PREFIX}widget_trend_expense", "")
                ?.split('|')
                ?.map { it.toLongOrNull() ?: 0L }
                .orEmpty()

            if (isHidden) {
                views.setImageViewBitmap(R.id.img_large_trend_chart, null)
                views.setTextViewText(R.id.tv_large_trend_labels, "••••••••")
                return
            }

            views.setImageViewBitmap(R.id.img_large_trend_chart, createTrendChart(income, expense))
            views.setTextViewText(R.id.tv_large_trend_labels, labels.joinToString(" "))
        }

        private fun createTrendChart(income: List<Long>, expense: List<Long>): Bitmap {
            val width = 600
            val height = 140
            val bottom = height - 3f
            val chartHeight = height - 12f
            val maxValue = max(
                1L,
                max(income.maxOrNull() ?: 0L, expense.maxOrNull() ?: 0L)
            ).toFloat() * 1.15f
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#343B47")
                strokeWidth = 1f
            }
            val incomePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#43A047")
            }
            val expensePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#FF5252")
            }

            for (index in 0..3) {
                val y = 4f + (chartHeight / 3f * index)
                canvas.drawLine(0f, y, width.toFloat(), y, gridPaint)
            }

            val slotWidth = width / 12f
            val barWidth = 9f
            for (index in 0 until 12) {
                val incomeValue = income.getOrElse(index) { 0L }
                val expenseValue = expense.getOrElse(index) { 0L }
                val incomeHeight = if (incomeValue == 0L) 0f else max(2f, incomeValue / maxValue * chartHeight)
                val expenseHeight = if (expenseValue == 0L) 0f else max(2f, expenseValue / maxValue * chartHeight)
                val center = slotWidth * index + slotWidth / 2f
                canvas.drawRoundRect(
                    center - barWidth - 2f,
                    bottom - incomeHeight,
                    center - 2f,
                    bottom,
                    3f,
                    3f,
                    incomePaint
                )
                canvas.drawRoundRect(
                    center + 2f,
                    bottom - expenseHeight,
                    center + barWidth + 2f,
                    bottom,
                    3f,
                    3f,
                    expensePaint
                )
            }
            return bitmap
        }
    }
}
