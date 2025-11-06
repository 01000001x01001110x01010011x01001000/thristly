package com.example.thristly

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object NotificationUtils {
    private const val CHANNEL_ID = "thristly_channel_id"

    fun show(context: Context, title: String, body: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Use a REMINDER-like channel; do NOT setBypassDnd (Samsung may show tips for alarm-like channels)
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Thristly Reminders",
                NotificationManager.IMPORTANCE_HIGH   // high so it’s visible, but not an ALARM category
            ).apply {
                description = "Hydration reminders"
                // remove: setBypassDnd(true)
            }
            nm.createNotificationChannel(ch)
        }

        val n = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_thristly)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER) // <-- not ALARM
            .build()

        nm.notify(((System.currentTimeMillis() / 1000) % Int.MAX_VALUE).toInt(), n)
    }
}
