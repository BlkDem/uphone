package com.uphone.uphone_client

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        @Volatile
        var isInForeground = false
            private set
    }

    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private var callChannel: MethodChannel? = null
    private var pendingCallData: Map<String, String>? = null

    private fun isCallIntent(intent: Intent?): Boolean {
        return intent?.hasExtra("call_action") == true
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    private fun dismissKeyguard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (keyguardManager.isKeyguardLocked) {
                keyguardManager.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() {}
                    override fun onDismissCancelled() {}
                    override fun onDismissError() {}
                })
            }
        }
    }

    private fun checkOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.uphone/ringtone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRingtone" -> {
                        startRingtone()
                        result.success(null)
                    }
                    "stopRingtone" -> {
                        stopRingtone()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        callChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.uphone/call_screen")
        callChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showOverLockScreen" -> {
                    showOverLockScreen()
                    result.success(null)
                }
                "cancelCallNotification" -> {
                    val callId = call.argument<String>("callId") ?: ""
                    if (callId.isNotEmpty()) {
                        CallNotificationService.clearCallHandled(callId)
                    }
                    CallNotificationService.cancelCallNotification(this)
                    CallOverlayService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.uphone/ws_service")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startWsService" -> {
                        val wsUrl = call.argument<String>("wsUrl") ?: ""
                        val token = call.argument<String>("token") ?: ""
                        WsKeepAliveService.start(this, wsUrl, token)
                        result.success(true)
                    }
                    "stopWsService" -> {
                        WsKeepAliveService.stop(this)
                        result.success(true)
                    }
                    "readWsDebugLog" -> {
                        result.success(WsKeepAliveService.readDebugLog(this))
                    }
                    else -> result.notImplemented()
                }
            }

        pendingCallData?.let { data ->
            callChannel?.invokeMethod("onCallIntent", data)
            pendingCallData = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isCallIntent(intent)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            showOverLockScreen()
            dismissKeyguard()
        }
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val callAction = intent.getStringExtra("call_action") ?: return
        val callId = intent.getStringExtra("call_id") ?: ""
        if (callId.isNotEmpty()) {
            CallNotificationService.clearCallHandled(callId)
        }
        CallNotificationService.cancelCallNotification(this)
        WsKeepAliveService.cancelCallNotification(this)
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            nm.cancel(CallOverlayService.NOTIFICATION_ID)
        } catch (_: Exception) {}
        val data = mapOf(
            "call_action" to callAction,
            "call_id" to (intent.getStringExtra("call_id") ?: ""),
            "from_user" to (intent.getStringExtra("from_user") ?: ""),
            "from_name" to (intent.getStringExtra("from_name") ?: "Unknown"),
            "call_type" to (intent.getStringExtra("call_type") ?: "video"),
            "is_group" to (intent.getBooleanExtra("is_group", false).toString()),
        )

        if (callChannel != null) {
            callChannel?.invokeMethod("onCallIntent", data)
        } else {
            pendingCallData = data
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkOverlayPermission()
        if (isCallIntent(intent)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            showOverLockScreen()
            dismissKeyguard()
        }
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
    }

    override fun onPause() {
        super.onPause()
        isInForeground = false
    }

    @Suppress("DEPRECATION")
    private fun getVibrator(): Vibrator {
        if (vibrator != null) return vibrator!!
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        return vibrator!!
    }

    private fun startRingtone() {
        stopRingtone()

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

        val vib = getVibrator()
        val timings = longArrayOf(0, 400, 200, 400, 200, 400, 800)
        val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vib.vibrate(VibrationEffect.createWaveform(timings, amplitudes, 0))
        } else {
            @Suppress("DEPRECATION")
            vib.vibrate(timings, 0)
        }
    }

    private fun stopRingtone() {
        ringtone?.let {
            if (it.isPlaying) it.stop()
        }
        ringtone = null
        getVibrator().cancel()
    }

    override fun onDestroy() {
        stopRingtone()
        super.onDestroy()
    }
}
