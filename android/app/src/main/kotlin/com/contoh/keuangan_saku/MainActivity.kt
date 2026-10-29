package com.contoh.keuangan_saku

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 2002
    }

    private val CHANNEL = "com.contoh.keuangan_saku/widget"
    private val reminderChannel = "com.contoh.keuangan_saku/daily_reminder"
    private var pendingAction: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        requestNotificationPermission()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE,
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        when (intent?.action) {
            WidgetHelper.ACTION_QUICK_ADD_EXPENSE -> {
                pendingAction = "expense"
            }
            WidgetHelper.ACTION_QUICK_ADD_INCOME -> {
                pendingAction = "income"
            }
            WidgetHelper.ACTION_QUICK_ADD -> {
                pendingAction = "add"
            }
        }
        dispatchPendingAction()
    }

    private fun dispatchPendingAction() {
        val action = pendingAction ?: return
        methodChannel?.invokeMethod("onQuickAction", action)
        pendingAction = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> {
                    WidgetHelper.updateAllWidgets(this)
                    result.success(true)
                }
                "getInitialAction" -> {
                    val action = pendingAction
                    pendingAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, reminderChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleDailyReminder" -> {
                        DailyReminderReceiver.schedule(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        dispatchPendingAction()
    }
}
