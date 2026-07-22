package com.uphone.uphone_client

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
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

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
                    CallNotificationService.cancelCallNotification(this)
                    result.success(null)
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
            showOverLockScreen()
        }
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val callAction = intent.getStringExtra("call_action") ?: return
        CallNotificationService.cancelCallNotification(this)
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
        if (isCallIntent(intent)) {
            showOverLockScreen()
        }
        handleIntent(intent)
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
