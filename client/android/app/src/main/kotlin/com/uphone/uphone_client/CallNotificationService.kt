package com.uphone.uphone_client

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class CallNotificationService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: ""

        if (type == "call-request" || type == "call-invite") {
            val callId = data["call_id"] ?: ""
            if (!tryMarkCallHandled(callId)) {
                return
            }
            launchCallOverlay(data)
            return
        }

        super.onMessageReceived(message)
    }

    @Suppress("DEPRECATION")
    private fun launchCallOverlay(data: Map<String, String>) {
        val callId = data["call_id"] ?: return
        val fromUserId = data["from_user"] ?: ""
        val fromName = data["from_name"] ?: "Unknown"
        val callType = data["call_type"] ?: "video"
        val isGroup = data["type"] == "call-invite"

        WsKeepAliveService.debugLog(this, "FCM: handling call $callId, fg=${MainActivity.isInForeground}")

        if (MainActivity.isInForeground) {
            WsKeepAliveService.debugLog(this, "FCM: app in foreground, Flutter handles")
            return
        }

        val overlayIntent = Intent(this, CallOverlayService::class.java).apply {
            putExtra("call_id", callId)
            putExtra("from_user", fromUserId)
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
            WsKeepAliveService.debugLog(this, "FCM: overlay started")
        } catch (e: Exception) {
            WsKeepAliveService.debugLog(this, "FCM overlay failed: ${e.message}")
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("call_action", "SHOW")
                putExtra("call_id", callId)
                putExtra("from_user", fromUserId)
                putExtra("from_name", fromName)
                putExtra("call_type", callType)
                putExtra("is_group", isGroup)
            }
            startActivity(intent)
        }
    }

    companion object {
        const val NOTIFICATION_ID = 9999
        private val handledCallIds = mutableSetOf<String>()

        @Synchronized
        fun markCallHandled(callId: String) {
            handledCallIds.add(callId)
        }

        fun tryMarkCallHandled(callId: String): Boolean {
            synchronized(handledCallIds) {
                if (handledCallIds.contains(callId)) return false
                handledCallIds.add(callId)
                return true
            }
        }

        fun isCallHandled(callId: String): Boolean {
            synchronized(handledCallIds) {
                return handledCallIds.contains(callId)
            }
        }

        fun cancelCallNotification(context: Context) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID)
        }
    }
}
