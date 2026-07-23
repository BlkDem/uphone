package com.uphone.uphone_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
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
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView

class CallOverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "uphone_overlay_min"
        const val NOTIFICATION_ID = 9998
        const val TIMEOUT_MS = 60_000L

        fun stop(context: Context) {
            context.stopService(Intent(context, CallOverlayService::class.java))
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
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

        dismissOverlay()
        stopRingtone()

        startForeground(NOTIFICATION_ID, buildNotification(fromName))

        try {
            showOverlay(callId, fromName, fromUser, callType, isGroup)
            startRingtoneAndVibrate()
            WsKeepAliveService.debugLog(this, "Overlay shown successfully for $callId")
        } catch (e: Exception) {
            WsKeepAliveService.debugLog(this, "Overlay FAILED: ${e.message}")
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("call_action", "SHOW")
                putExtra("call_id", callId)
                putExtra("from_user", fromUser)
                putExtra("from_name", fromName)
                putExtra("call_type", callType)
                putExtra("is_group", isGroup)
            }
            startActivity(launchIntent)
        }

        timeoutRunnable = Runnable { dismissAndStop() }
        handler.postDelayed(timeoutRunnable!!, TIMEOUT_MS)

        return START_NOT_STICKY
    }

    private fun showOverlay(
        callId: String,
        fromName: String,
        fromUser: String,
        callType: String,
        isGroup: Boolean
    ) {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.call_overlay, null)

        view.findViewById<TextView>(R.id.caller_name).text = fromName
        view.findViewById<TextView>(R.id.call_type).text =
            if (callType == "video") "Incoming video call" else "Incoming audio call"

        val rejectBg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(0xFFE53935.toInt())
        }
        val rejectIcon = view.findViewById<ImageView>(R.id.reject_icon)
        rejectIcon.background = rejectBg
        rejectIcon.setImageResource(R.drawable.ic_call_reject)
        rejectIcon.setColorFilter(0xFFFFFFFF.toInt())

        val acceptBg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(0xFF43A047.toInt())
        }
        val acceptIcon = view.findViewById<ImageView>(R.id.accept_icon)
        acceptIcon.background = acceptBg
        acceptIcon.setImageResource(R.drawable.ic_call_accept)
        acceptIcon.setColorFilter(0xFFFFFFFF.toInt())

        view.findViewById<View>(R.id.btn_accept).setOnClickListener {
            launchCallAction("ACCEPT", callId, fromUser, fromName, callType, isGroup)
            dismissAndStop()
        }

        view.findViewById<View>(R.id.btn_reject).setOnClickListener {
            launchCallAction("REJECT", callId, fromUser, fromName, callType, isGroup)
            dismissAndStop()
        }

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        windowManager?.addView(view, params)
        overlayView = view
    }

    @Suppress("DEPRECATION")
    private fun launchCallAction(
        action: String,
        callId: String,
        fromUser: String,
        fromName: String,
        callType: String,
        isGroup: Boolean
    ) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_NO_USER_ACTION
            )
            putExtra("call_action", action)
            putExtra("call_id", callId)
            putExtra("from_user", fromUser)
            putExtra("from_name", fromName)
            putExtra("call_type", callType)
            putExtra("is_group", isGroup)
        }
        startActivity(intent)
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

    private fun dismissOverlay() {
        overlayView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
            overlayView = null
        }
    }

    private fun dismissAndStop() {
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        stopRingtone()
        dismissOverlay()
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
            },
            PendingIntent.FLAG_IMMUTABLE
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
