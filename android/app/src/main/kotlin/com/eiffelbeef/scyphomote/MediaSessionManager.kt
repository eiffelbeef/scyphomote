package com.eiffelbeef.scyphomote

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import android.net.Uri
import java.net.URL

class MediaSessionManager(private val context: Context, private val methodChannel: MethodChannel) {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private val activeSessions = mutableMapOf<String, SessionHolder>()
    private val notificationManager = NotificationManagerCompat.from(context)

    companion object {
        private const val CHANNEL_ID = "jellyfin_media_controls"
        private const val CHANNEL_NAME = "Jellyfin Media Controls"
        private const val BASE_NOTIFICATION_ID = 20000

        const val ACTION_PREVIOUS = "com.eiffelbeef.scyphomote.ACTION_PREVIOUS"
        const val ACTION_PLAY_PAUSE = "com.eiffelbeef.scyphomote.ACTION_PLAY_PAUSE"
        const val ACTION_NEXT = "com.eiffelbeef.scyphomote.ACTION_NEXT"
        const val ACTION_STOP = "com.eiffelbeef.scyphomote.ACTION_STOP"
        const val EXTRA_SESSION_ID = "extra_session_id"
    }

    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val sessionId = intent?.getStringExtra(EXTRA_SESSION_ID) ?: return
            val action = when (intent.action) {
                ACTION_PREVIOUS -> "previous"
                ACTION_PLAY_PAUSE -> "playPause"
                ACTION_NEXT -> "next"
                ACTION_STOP -> "stop"
                else -> return
            }
            sendMediaCommand(sessionId, action)
        }
    }

    init {
        createNotificationChannel()
        val filter = IntentFilter().apply {
            addAction(ACTION_PREVIOUS)
            addAction(ACTION_PLAY_PAUSE)
            addAction(ACTION_NEXT)
            addAction(ACTION_STOP)
        }
        ContextCompat.registerReceiver(
            context,
            actionReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Media controls for active Jellyfin sessions"
                setSound(null, null)
                enableVibration(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun updateSessions(sessionDataList: List<Map<String, Any?>>) {
        try {
            val currentSessionIds = sessionDataList.mapNotNull { it["sessionId"] as? String }.toSet()

            // Remove sessions no longer active
            val removedIds = activeSessions.keys.filter { !currentSessionIds.contains(it) }
            for (id in removedIds) {
                removeSession(id)
            }

            // Create or update active sessions
            for ((index, data) in sessionDataList.withIndex()) {
                val sessionId = data["sessionId"] as? String ?: continue
                val title = data["title"] as? String ?: "Jellyfin"
                val artist = data["artist"] as? String ?: ""
                val album = data["album"] as? String ?: ""
                val deviceName = data["deviceName"] as? String ?: ""
                val isPlaying = data["isPlaying"] as? Boolean ?: false
                val artworkUrl = data["artworkUrl"] as? String
                val positionMs = (data["positionMs"] as? Number)?.toLong() ?: 0L
                val durationMs = (data["durationMs"] as? Number)?.toLong() ?: 0L
                val supportsRemoteControl = data["supportsRemoteControl"] as? Boolean ?: false
                val canPlayPause = data["canPlayPause"] as? Boolean ?: supportsRemoteControl
                val canNext = data["canNext"] as? Boolean ?: supportsRemoteControl
                val canPrevious = data["canPrevious"] as? Boolean ?: supportsRemoteControl
                val canStop = data["canStop"] as? Boolean ?: supportsRemoteControl
                val canSeek = data["canSeek"] as? Boolean ?: false

                val holder = activeSessions.getOrPut(sessionId) {
                    val notificationId = BASE_NOTIFICATION_ID + activeSessions.size + index
                    createHolder(sessionId, notificationId)
                }

                updateSessionHolder(
                    holder, sessionId, title, artist, album, deviceName, isPlaying, artworkUrl, positionMs, durationMs,
                    supportsRemoteControl, canPlayPause, canNext, canPrevious, canStop, canSeek
                )
            }
        } catch (e: Exception) {
            Log.e("MediaSessionManager", "Error updating sessions", e)
        }
    }

    private fun createHolder(sessionId: String, notificationId: Int): SessionHolder {
        val mediaSession = MediaSessionCompat(context, "Jellyfin_$sessionId").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = sendMediaCommand(sessionId, "playPause")
                override fun onPause() = sendMediaCommand(sessionId, "playPause")
                override fun onSkipToNext() = sendMediaCommand(sessionId, "next")
                override fun onSkipToPrevious() = sendMediaCommand(sessionId, "previous")
                override fun onStop() = sendMediaCommand(sessionId, "stop")
                override fun onSeekTo(pos: Long) {
                    sendMediaCommand(sessionId, "seek", mapOf("positionMs" to pos))
                }
            })
            isActive = true
        }
        return SessionHolder(sessionId, notificationId, mediaSession)
    }

    private fun updateSessionHolder(
        holder: SessionHolder,
        sessionId: String,
        title: String,
        artist: String,
        album: String,
        deviceName: String,
        isPlaying: Boolean,
        artworkUrl: String?,
        positionMs: Long,
        durationMs: Long,
        supportsRemoteControl: Boolean,
        canPlayPause: Boolean,
        canNext: Boolean,
        canPrevious: Boolean,
        canStop: Boolean,
        canSeek: Boolean
    ) {
        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        var actions = 0L

        if (supportsRemoteControl) {
            if (canPlayPause) {
                actions = actions or PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE
            }
            if (canNext) {
                actions = actions or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
            }
            if (canPrevious) {
                actions = actions or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            }
            if (canStop) {
                actions = actions or PlaybackStateCompat.ACTION_STOP
            }
        }
        if (canSeek) {
            actions = actions or PlaybackStateCompat.ACTION_SEEK_TO
        }

        val speed = if (isPlaying) 1.0f else 0.0f
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(actions)
            .setState(state, positionMs, speed)
            .build()

        holder.mediaSession.setPlaybackState(playbackState)

        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist.ifEmpty { deviceName })
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album.ifEmpty { deviceName })
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)

        holder.mediaSession.setMetadata(metadataBuilder.build())

        // Display Notification with MediaStyle
        showNotification(
            holder, sessionId, title, artist.ifEmpty { deviceName }, isPlaying, holder.currentBitmap,
            supportsRemoteControl, canPlayPause, canNext, canPrevious, canStop
        )

        // Load Artwork Asynchronously if updated
        if (artworkUrl != null && artworkUrl != holder.lastArtworkUrl) {
            holder.lastArtworkUrl = artworkUrl
            scope.launch(Dispatchers.IO) {
                val bitmap = loadBitmap(artworkUrl)
                if (bitmap != null) {
                    holder.currentBitmap = bitmap
                    withContext(Dispatchers.Main) {
                        val updatedMetadata = MediaMetadataCompat.Builder(holder.mediaSession.controller.metadata)
                            .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap)
                            .putBitmap(MediaMetadataCompat.METADATA_KEY_ART, bitmap)
                            .build()
                        holder.mediaSession.setMetadata(updatedMetadata)
                        showNotification(
                            holder, sessionId, title, artist.ifEmpty { deviceName }, isPlaying, bitmap,
                            supportsRemoteControl, canPlayPause, canNext, canPrevious, canStop
                        )
                    }
                }
            }
        }
    }

    private fun showNotification(
        holder: SessionHolder,
        sessionId: String,
        title: String,
        subtitle: String,
        isPlaying: Boolean,
        bitmap: Bitmap?,
        supportsRemoteControl: Boolean,
        canPlayPause: Boolean,
        canNext: Boolean,
        canPrevious: Boolean,
        canStop: Boolean
    ) {
        val contentPendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("scyphomote://remote?session_id=$sessionId")
        )
        holder.mediaSession.setSessionActivity(contentPendingIntent)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setLargeIcon(bitmap)
            .setContentIntent(contentPendingIntent)
            .setOngoing(isPlaying)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSound(null)

        val compactActions = mutableListOf<Int>()
        var actionIndex = 0

        if (supportsRemoteControl) {
            if (canPrevious) {
                val prevPending = createActionPendingIntent(ACTION_PREVIOUS, sessionId, holder.notificationId + 1)
                builder.addAction(android.R.drawable.ic_media_previous, "Previous", prevPending)
                compactActions.add(actionIndex++)
            }
            if (canPlayPause) {
                val playPausePending = createActionPendingIntent(ACTION_PLAY_PAUSE, sessionId, holder.notificationId + 2)
                val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
                val playPauseTitle = if (isPlaying) "Pause" else "Play"
                builder.addAction(playPauseIcon, playPauseTitle, playPausePending)
                compactActions.add(actionIndex++)
            }
            if (canNext) {
                val nextPending = createActionPendingIntent(ACTION_NEXT, sessionId, holder.notificationId + 3)
                builder.addAction(android.R.drawable.ic_media_next, "Next", nextPending)
                compactActions.add(actionIndex++)
            }
            if (canStop) {
                val stopPending = createActionPendingIntent(ACTION_STOP, sessionId, holder.notificationId + 4)
                builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPending)
            }
        }

        val mediaStyle = MediaStyle().setMediaSession(holder.mediaSession.sessionToken)
        if (compactActions.isNotEmpty()) {
            mediaStyle.setShowActionsInCompactView(*compactActions.toIntArray())
        }

        builder.setStyle(mediaStyle)

        try {
            notificationManager.notify(holder.notificationId, builder.build())
        } catch (_: Exception) {}
    }

    private fun createActionPendingIntent(action: String, sessionId: String, requestCode: Int): PendingIntent {
        val intent = Intent(action).apply {
            putExtra(EXTRA_SESSION_ID, sessionId)
            setPackage(context.packageName)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun loadBitmap(urlStr: String): Bitmap? {
        return try {
            val url = URL(urlStr)
            val connection = url.openConnection()
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.getInputStream().use { inputStream ->
                BitmapFactory.decodeStream(inputStream)
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun sendMediaCommand(sessionId: String, command: String, extraArgs: Map<String, Any?> = emptyMap()) {
        scope.launch(Dispatchers.Main) {
            val args = mutableMapOf<String, Any?>("sessionId" to sessionId, "command" to command)
            args.putAll(extraArgs)
            methodChannel.invokeMethod("onMediaCommand", args)
        }
    }

    private fun removeSession(sessionId: String) {
        val holder = activeSessions.remove(sessionId) ?: return
        try {
            notificationManager.cancel(holder.notificationId)
        } catch (_: Exception) {}
        holder.mediaSession.isActive = false
        holder.mediaSession.release()
    }

    fun cleanUp() {
        try {
            context.unregisterReceiver(actionReceiver)
        } catch (e: IllegalArgumentException) {}
        for (id in activeSessions.keys.toList()) {
            removeSession(id)
        }
    }

    private data class SessionHolder(
        val sessionId: String,
        val notificationId: Int,
        val mediaSession: MediaSessionCompat,
        var lastArtworkUrl: String? = null,
        var currentBitmap: Bitmap? = null
    )
}
