package com.uphone.uphone_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class CallOverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "uphone_overlay_min"
        const val NOTIFICATION_ID = 9998
        const val TIMEOUT_MS = 60_000L

        fun stop(context: Context) {
            context.stopService(Intent(context, CallOverlayService::class.java))
        }
    }

    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private val handler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null
    private var currentCallId = ""
    private var currentFromUser = ""
    private var currentCallType = "video"
    private var currentIsGroup = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "REJECT") {
            val callId = intent.getStringExtra("call_id") ?: ""
            if (callId.isNotEmpty()) {
                CallNotificationService.clearCallHandled(callId)
            }
            dismissAndStop()
            return START_NOT_STICKY
        }

        val callId = intent?.getStringExtra("call_id") ?: run { stopSelf(); return START_NOT_STICKY }

        val fromName = intent.getStringExtra("from_name") ?: "Unknown"
        val fromUser = intent.getStringExtra("from_user") ?: ""
        val callType = intent.getStringExtra("call_type") ?: "video"
        val isGroup = intent.getBooleanExtra("is_group", false)

        currentCallId = callId
        currentFromUser = fromUser
        currentCallType = callType
        currentIsGroup = isGroup

        stopRingtone()

        startForeground(NOTIFICATION_ID, buildNotification(fromName))

        startRingtoneAndVibrate()
        WsKeepAliveService.debugLog(this, "Incoming call ringing for $callId")

        timeoutRunnable = Runnable { dismissAndStop() }
        handler.postDelayed(timeoutRunnable!!, TIMEOUT_MS)

        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun startRingtoneAndVibrate() {
        val uri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ringtone = RingtoneManager.getRingtone(applicationContext, uri)
        ringtone?.let { rt ->
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                rt.audioAttributes = attrs
            }
            rt.play()
        }

        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val timings = longArrayOf(0, 400, 200, 400, 200, 400, 800)
        val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(timings, amplitudes, 0))
        } else {
            vibrator?.vibrate(timings, 0)
        }
    }

    private fun stopRingtone() {
        ringtone?.let { if (it.isPlaying) it.stop() }
        ringtone = null
        vibrator?.cancel()
        vibrator = null
    }

    private fun dismissAndStop() {
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        stopRingtone()
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {}
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        dismissAndStop()
        super.onDestroy()
    }

    private fun buildNotification(callerName: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Call Service",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Active call"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(channel)

        val fullScreenIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("call_action", "SHOW")
                putExtra("call_id", currentCallId)
                putExtra("from_user", currentFromUser)
                putExtra("from_name", callerName)
                putExtra("call_type", currentCallType)
                putExtra("is_group", currentIsGroup)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val acceptIntent = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("call_action", "ACCEPT")
                putExtra("call_id", currentCallId)
                putExtra("from_user", currentFromUser)
                putExtra("from_name", callerName)
                putExtra("call_type", currentCallType)
                putExtra("is_group", currentIsGroup)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val rejectIntent = PendingIntent.getService(
            this,
            2,
            Intent(this, CallOverlayService::class.java).apply {
                action = "REJECT"
                putExtra("call_id", currentCallId)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("Звонит $callerName")
            .setFullScreenIntent(fullScreenIntent, true)
            .addAction(Notification.Action.Builder(
                null, "Принять", acceptIntent
            ).build())
            .addAction(Notification.Action.Builder(
                null, "Отклонить", rejectIntent
            ).build())
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setDefaults(0)
            .build()
    }
}
