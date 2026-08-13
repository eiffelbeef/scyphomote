package com.eiffelbeef.scyphomote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.eiffelbeef.scyphomote/screen"
    private val EVENT_CHANNEL = "com.eiffelbeef.scyphomote/screen_events"

    private var screenReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isScreenInteractive") {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(powerManager.isInteractive)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    screenReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            when (intent?.action) {
                                Intent.ACTION_SCREEN_ON -> {
                                    events?.success("screen_on")
                                }
                                Intent.ACTION_USER_PRESENT -> {
                                    events?.success("unlocked")
                                }
                                Intent.ACTION_SCREEN_OFF -> {
                                    events?.success("screen_off")
                                }
                            }
                        }
                    }
                    val filter = IntentFilter().apply {
                        addAction(Intent.ACTION_SCREEN_ON)
                        addAction(Intent.ACTION_SCREEN_OFF)
                        addAction(Intent.ACTION_USER_PRESENT)
                    }
                    ContextCompat.registerReceiver(
                        applicationContext,
                        screenReceiver,
                        filter,
                        ContextCompat.RECEIVER_NOT_EXPORTED
                    )
                }

                override fun onCancel(arguments: Any?) {
                    screenReceiver?.let {
                        try {
                            unregisterReceiver(it)
                        } catch (e: Exception) {}
                        screenReceiver = null
                    }
                }
            }
        )
    }
}
