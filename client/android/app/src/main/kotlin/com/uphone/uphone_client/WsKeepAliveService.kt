package com.uphone.uphone_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

class WsKeepAliveService : Service() {

    companion object {
        private const val TAG = "WsKeepAlive"
        private const val CHANNEL_ID = "uphone_ws_service"
        private const val NOTIFICATION_ID = 9997
        private const val ACTION_START = "com.uphone.WS_START"
        private const val ACTION_UPDATE_TOKEN = "com.uphone.WS_UPDATE_TOKEN"
        private const val ACTION_STOP = "com.uphone.WS_STOP"
        private const val EXTRA_WS_URL = "ws_url"
        private const val EXTRA_TOKEN = "token"

        @Volatile private var runningToken: String? = null

        fun debugLog(context: Context, msg: String) {
            try {
                val dir = File(context.filesDir, "logs")
                dir.mkdirs()
                val file = File(dir, "ws_debug.log")
                val sdf = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)
                FileWriter(file, true).use { fw ->
                    fw.appendLine("${sdf.format(Date())} $msg")
                }
            } catch (_: Exception) {}
        }

        fun readDebugLog(context: Context): String {
            return try {
                val file = File(File(context.filesDir, "logs"), "ws_debug.log")
                if (file.exists()) file.readText() else "no log file"
            } catch (e: Exception) { e.message ?: "error" }
        }

        fun cancelCallNotification(context: Context) {
            CallNotificationService.cancelCallNotification(context)
            CallOverlayService.stop(context)
        }

        fun start(context: Context, wsUrl: String, token: String) {
            if (runningToken == token) {
                debugLog(context, "start() SKIP same token")
                return
            }
            debugLog(context, "start() url=$wsUrl tokenLen=${token.length}")
            runningToken = token
            val intent = Intent(context, WsKeepAliveService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_WS_URL, wsUrl)
                putExtra(EXTRA_TOKEN, token)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            debugLog(context, "stop() called")
            runningToken = null
            context.stopService(Intent(context, WsKeepAliveService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var webSocket: WebSocket? = null
    private var wsUrl: String? = null
    private var token: String? = null
    private var isConnected = false
    private var isConnecting = false
    private var shouldReconnect = true

    private val pingRunnable = object : Runnable {
        override fun run() {
            if (isConnected) {
                try {
                    val ping = JSONObject().put("type", "ping").toString()
                    webSocket?.send(ping)
                } catch (_: Exception) {}
            }
            handler.postDelayed(this, 30_000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val newUrl = intent.getStringExtra(EXTRA_WS_URL)
                val newToken = intent.getStringExtra(EXTRA_TOKEN)
                if (newUrl == null || newToken == null) {
                    debugLog(this, "ERROR: missing params")
                    stopSelf()
                    return START_NOT_STICKY
                }

                if (wsUrl == newUrl && token == newToken && (isConnected || isConnecting)) {
                    debugLog(this, "Already connected with same params, skipping")
                    return START_NOT_STICKY
                }

                wsUrl = newUrl
                token = newToken
                shouldReconnect = true
                debugLog(this, "onStartCommand START url=$wsUrl tokenLen=${newToken.length}")
                startForegroundWithNotification()
                connectWebSocket()
            }
            ACTION_STOP -> {
                debugLog(this, "onStartCommand STOP")
                shouldReconnect = false
                disconnect()
                tryStopForeground()
                stopSelf()
            }
            else -> {
                debugLog(this, "onStartCommand null/unknown action, stopping")
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundWithNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Connection Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Maintains connection for incoming calls"
        }
        nm.createNotificationChannel(channel)

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("UPhone")
            .setContentText("Connected")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun connectWebSocket() {
        if (isConnecting) {
            debugLog(this, "connectWebSocket() SKIP already connecting")
            return
        }

        handler.removeCallbacks(pingRunnable)
        try { webSocket?.close(1000, null) } catch (_: Exception) {}
        webSocket = null
        isConnected = false
        isConnecting = true

        val url = wsUrl ?: run { isConnecting = false; return }
        val tok = token ?: run { isConnecting = false; return }

        val request = Request.Builder()
            .url("$url?token=$tok")
            .build()

        val client = OkHttpClient.Builder()
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .pingInterval(30, TimeUnit.SECONDS)
            .build()

        debugLog(this, "Connecting to $url")
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                isConnecting = false
                debugLog(this@WsKeepAliveService, "WS connected OK")
                isConnected = true
                handler.post(pingRunnable)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    val msg = JSONObject(text)
                    val type = msg.optString("type", "")

                    if (type == "call-request" || type == "call-invite") {
                        debugLog(this@WsKeepAliveService, "CALL INCOMING! type=$type msg=$text")
                        handler.post { handleCallMessage(msg) }
                    } else if (type == "call-reject" || type == "call-end") {
                        debugLog(this@WsKeepAliveService, "CALL CANCELLED! type=$type msg=$text")
                        handler.post { handleCallCancelled(msg) }
                    }
                } catch (e: Exception) {
                    debugLog(this@WsKeepAliveService, "WS parse error: ${e.message}")
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                debugLog(this@WsKeepAliveService, "WS closing code=$code reason=$reason")
                webSocket.close(1000, null)
                isConnecting = false
                isConnected = false
                handler.removeCallbacks(pingRunnable)
                if (shouldReconnect) scheduleReconnect()
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                debugLog(this@WsKeepAliveService, "WS closed code=$code")
                isConnecting = false
                isConnected = false
                handler.removeCallbacks(pingRunnable)
                if (shouldReconnect) scheduleReconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                debugLog(this@WsKeepAliveService, "WS FAILED: ${t.message}")
                isConnecting = false
                isConnected = false
                handler.removeCallbacks(pingRunnable)
                if (shouldReconnect) scheduleReconnect()
            }
        })
    }

    private fun scheduleReconnect() {
        handler.postDelayed({
            if (shouldReconnect && !isConnected && !isConnecting) {
                connectWebSocket()
            }
        }, 3_000L)
    }

    @Suppress("DEPRECATION")
    private fun handleCallMessage(msg: JSONObject) {
        val payload = msg.optJSONObject("payload") ?: JSONObject()

        val callId = msg.optString("call_id", "")
        val fromUser = msg.optString("from_user", "")
        val fromName = payload.optString("from_name", "Unknown")
        val callType = payload.optString("call_type", "video")
        val chatId = payload.optString("chat_id", "")
        val isGroup = msg.optString("type", "") == "call-invite"

        if (callId.isEmpty()) {
            debugLog(this, "No call_id in message, skipping")
            return
        }

        debugLog(this, "Call incoming: $callId from=$fromUser name=$fromName type=$callType")

        if (!CallNotificationService.tryMarkCallHandled(callId)) {
            debugLog(this, "Already handled by another path, skipping")
            return
        }

        CallNotificationService.cancelCallNotification(this)

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "uphone:incoming_call"
        )
        wakeLock.acquire(30_000L)
        debugLog(this, "WakeLock acquired, app foreground=${MainActivity.isInForeground}")

        if (MainActivity.isInForeground) {
            debugLog(this, "App in foreground, forwarding to Flutter via intent")
            fallbackToActivity(callId, fromUser, fromName, callType, isGroup)
            return
        }

        debugLog(this, "App NOT in foreground, starting overlay")
        val overlayIntent = Intent(this, CallOverlayService::class.java).apply {
            putExtra("call_id", callId)
            putExtra("from_user", fromUser)
            putExtra("from_name", fromName)
            putExtra("call_type", callType)
            putExtra("is_group", isGroup)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(overlayIntent)
            } else {
                startService(overlayIntent)
            }
            debugLog(this, "CallOverlayService started")
        } catch (e: Exception) {
            debugLog(this, "Overlay FAILED: ${e.message}")
        }
    }

    private fun handleCallCancelled(msg: JSONObject) {
        val callId = msg.optString("call_id", "")
        if (callId.isEmpty()) return

        debugLog(this, "Call cancelled remotely: $callId type=${msg.optString("type")}")

        CallNotificationService.clearCallHandled(callId)
        cancelCallNotification(this)
        CallOverlayService.stop(this)
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            nm.cancel(CallOverlayService.NOTIFICATION_ID)
        } catch (_: Exception) {}

        if (MainActivity.isInForeground) {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("call_action", "END")
                putExtra("call_id", callId)
            }
            try { startActivity(intent) } catch (_: Exception) {}
        }
    }

    private fun fallbackToActivity(
        callId: String,
        fromUser: String,
        fromName: String,
        callType: String,
        isGroup: Boolean
    ) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra("call_action", "SHOW")
            putExtra("call_id", callId)
            putExtra("from_user", fromUser)
            putExtra("from_name", fromName)
            putExtra("call_type", callType)
            putExtra("is_group", isGroup)
        }
        try {
            startActivity(intent)
            debugLog(this, "Fallback startActivity SUCCESS")
        } catch (e: Exception) {
            debugLog(this, "Fallback startActivity FAILED: ${e.message}")
        }
    }

    private fun disconnect() {
        handler.removeCallbacks(pingRunnable)
        shouldReconnect = false
        try {
            webSocket?.close(1000, "Service stopping")
        } catch (_: Exception) {}
        webSocket = null
        isConnected = false
        isConnecting = false
    }

    private fun tryStopForeground() {
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        disconnect()
        super.onDestroy()
    }
}
