package com.eiffelbeef.scyphomote

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class RemoteWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val isPremium = widgetData.getBoolean("is_premium", false)
            if (!isPremium) {
                // Render the LOCKED widget
                val views = RemoteViews(context.packageName, R.layout.widget_locked).apply {
                    val openPaywallIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("scyphomote://upgrade")
                    )
                    setOnClickPendingIntent(R.id.widget_locked_container, openPaywallIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
                return@forEach
            }

            var sessionId = widgetData.getString("widget_session_id_$widgetId", null)
            var deviceName = widgetData.getString("widget_device_name_$widgetId", null)

            // Adoption logic: If this widget is new/unconfigured, check for a pending pinning request
            if (sessionId == null) {
                val pendingSessionId = widgetData.getString("widget_pending_session_id", null)
                val pendingDeviceName = widgetData.getString("widget_pending_device_name", null)

                if (pendingSessionId != null) {
                    sessionId = pendingSessionId
                    deviceName = pendingDeviceName ?: "Scyphomote"

                    // Save to this specific widget and consume the pending request
                    widgetData.edit()
                        .putString("widget_session_id_$widgetId", sessionId)
                        .putString("widget_device_name_$widgetId", deviceName)
                        .remove("widget_pending_session_id")
                        .remove("widget_pending_device_name")
                        .apply()
                }
            }

            if (sessionId == null) {
                // Render the UNCONFIGURED widget
                val views = RemoteViews(context.packageName, R.layout.widget_unconfigured).apply {
                    val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("scyphomote://")
                    )
                    setOnClickPendingIntent(R.id.widget_unconfigured_container, openAppIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
                return@forEach
            }

            val views = RemoteViews(context.packageName, R.layout.widget_remote).apply {
                val uriStr = "scyphomote://remote?session_id=$sessionId"
                val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(uriStr)
                )
                setOnClickPendingIntent(R.id.widget_title, openAppIntent)

                fun getCommandIntent(command: String): android.app.PendingIntent {
                    val cmdUriStr = "scyphomote://widget_command/$command?session_id=$sessionId"
                    return HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse(cmdUriStr)
                    )
                }

                setOnClickPendingIntent(R.id.btn_up, getCommandIntent("up"))
                setOnClickPendingIntent(R.id.btn_down, getCommandIntent("down"))
                setOnClickPendingIntent(R.id.btn_left, getCommandIntent("left"))
                setOnClickPendingIntent(R.id.btn_right, getCommandIntent("right"))
                setOnClickPendingIntent(R.id.btn_ok, getCommandIntent("ok"))
                setOnClickPendingIntent(R.id.btn_play_pause, getCommandIntent("play_pause"))
                setOnClickPendingIntent(R.id.btn_stop, getCommandIntent("stop"))
                setOnClickPendingIntent(R.id.btn_back, getCommandIntent("back"))

                // Show the device name
                setTextViewText(R.id.widget_title, deviceName ?: "Scyphomote")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
