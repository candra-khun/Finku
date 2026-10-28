package com.contoh.keuangan_saku

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.contoh.keuangan_saku/widget"
    private var pendingAction: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
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

        dispatchPendingAction()
    }
}
