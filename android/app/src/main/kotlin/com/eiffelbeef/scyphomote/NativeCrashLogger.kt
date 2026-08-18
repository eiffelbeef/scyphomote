package com.eiffelbeef.scyphomote

import android.content.Context
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NativeCrashLogger {
    private var isHandlerInstalled = false

    fun init(context: Context) {
        if (isHandlerInstalled) return
        isHandlerInstalled = true

        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            record(context, "UncaughtException", throwable)
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    fun record(context: Context, tag: String, throwable: Throwable) {
        try {
            val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
            if (!appFlutterDir.exists()) {
                appFlutterDir.mkdirs()
            }
            val file = File(appFlutterDir, "crash_log.txt")
            val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
            val stringWriter = StringWriter()
            val printWriter = PrintWriter(stringWriter)
            throwable.printStackTrace(printWriter)
            val stackTraceStr = stringWriter.toString().lines().take(10).joinToString("\n")

            val entry = "[$timestamp]\n[NATIVE-$tag] ${throwable.javaClass.simpleName}: ${throwable.message}\n$stackTraceStr\n---\n"
            file.appendText(entry)
        } catch (e: Exception) {
            Log.e("NativeCrashLogger", "Failed to write crash log: ${e.message}")
        }
    }
}
