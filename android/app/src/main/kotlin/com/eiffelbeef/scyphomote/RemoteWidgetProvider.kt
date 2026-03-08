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
            val views = RemoteViews(context.packageName, R.layout.widget_remote).apply {
                // Determine layout actions using HomeWidgetBackgroundIntent
                // These trigger the Dart background function
                // This intent simply opens the app
                val sessionId = widgetData.getString("widget_session_id", null)
                val uriStr = if (sessionId != null) "scyphomote://remote?session_id=$sessionId" else "scyphomote://remote"
                val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(uriStr)
                )
                setOnClickPendingIntent(R.id.widget_title, openAppIntent)

                setOnClickPendingIntent(
                    R.id.btn_up,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("scyphomote://widget_command/up")
                    )
                )

                setOnClickPendingIntent(
                    R.id.btn_down,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("scyphomote://widget_command/down")
                    )
                )

                setOnClickPendingIntent(
                    R.id.btn_left,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("scyphomote://widget_command/left")
                    )
                )

                setOnClickPendingIntent(
                    R.id.btn_right,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("scyphomote://widget_command/right")
                    )
                )

                setOnClickPendingIntent(
                    R.id.btn_ok,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("scyphomote://widget_command/ok")
                    )
                )

                setOnClickPendingIntent(
                    R.id.btn_play_pause,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("scyphomote://widget_command/play_pause")
                    )
                )

                setOnClickPendingIntent(
                    R.id.btn_stop,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("scyphomote://widget_command/stop")
                    )
                )
                
                setOnClickPendingIntent(
                    R.id.btn_back,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("scyphomote://widget_command/back")
                    )
                )

                // Optional: show the device name if we have it
                val deviceName = widgetData.getString("widget_device_name", "Scyphomote")
                setTextViewText(R.id.widget_title, deviceName)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
