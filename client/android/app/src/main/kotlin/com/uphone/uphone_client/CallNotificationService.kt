package com.uphone.uphone_client

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class CallNotificationService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: ""

        if (type == "call-request" || type == "call-invite") {
            launchCallActivity(data)
        }

        super.onMessageReceived(message)
    }

    private fun launchCallActivity(data: Map<String, String>) {
        val callId = data["call_id"] ?: return
        val fromUserId = data["from_user"] ?: ""
        val fromName = data["from_name"] ?: "Unknown"
        val callType = data["call_type"] ?: "video"
        val isGroup = data["type"] == "call-invite"
        val title = data["title"] ?: "Incoming call"
        val body = data["body"] ?: "$fromName is calling..."

        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("call_action", "SHOW")
            putExtra("call_id", callId)
            putExtra("from_user", fromUserId)
            putExtra("from_name", fromName)
            putExtra("call_type", callType)
            putExtra("is_group", isGroup)
        }

        // Mechanism 1: direct startActivity (works on most devices with high-priority FCM)
        startActivity(intent)

        // Mechanism 2: fullScreenIntent notification (Android's guaranteed fallback)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Incoming Calls",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "UPhone incoming call notifications"
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
        }
        nm.createNotificationChannel(channel)

        val pendingIntent = PendingIntent.getActivity(
            this,
            callId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

        nm.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        const val CHANNEL_ID = "uphone_calls"
        const val NOTIFICATION_ID = 9999

        fun cancelCallNotification(context: Context) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID)
        }
    }
}
