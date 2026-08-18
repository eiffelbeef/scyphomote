package com.eiffelbeef.scyphomote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.eiffelbeef.scyphomote/screen"
    private val EVENT_CHANNEL = "com.eiffelbeef.scyphomote/screen_events"
    private val MEDIA_CONTROLS_CHANNEL = "com.eiffelbeef.scyphomote/media_controls"

    private var screenReceiver: BroadcastReceiver? = null
    private var mediaSessionManager: MediaSessionManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeCrashLogger.init(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isScreenInteractive") {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(powerManager.isInteractive)
            } else {
                result.notImplemented()
            }
        }

        val mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CONTROLS_CHANNEL)
        mediaSessionManager = MediaSessionManager(context, mediaChannel)

        mediaChannel.setMethodCallHandler { call, result ->
            if (call.method == "updateSessions") {
                val sessionsList = call.argument<List<Map<String, Any?>>>("sessions") ?: emptyList()
                mediaSessionManager?.updateSessions(sessionsList)
                result.success(true)
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
                        } catch (e: IllegalArgumentException) {
                            Log.w("MainActivity", "Screen receiver already unregistered: ${e.message}")
                        }
                        screenReceiver = null
                    }
                }
            }
        )
    }

    override fun onDestroy() {
        mediaSessionManager?.cleanUp()
        super.onDestroy()
    }
}
