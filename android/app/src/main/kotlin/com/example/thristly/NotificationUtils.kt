// package declaration for this Kotlin file
package com.example.thristly

// import for NotificationChannel class
import android.app.NotificationChannel
// import for NotificationManager class
import android.app.NotificationManager
// import for Context type
import android.content.Context
// import to check Android OS build version
import android.os.Build
// import for NotificationCompat helper
import androidx.core.app.NotificationCompat
import com.example.thristify.R

// singleton object to hold notification helper functions
object NotificationUtils {
    // constant for the channel ID used for notifications
    private const val CHANNEL_ID = "thristly_channel_id"

    // public function to show a notification with title and body
    fun show(context: Context, title: String, body: String) {
        // obtain the system NotificationManager service
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // only create a notification channel on Android O and above
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // create a NotificationChannel with a user-visible name and importance
            // Use a REMINDER-like channel; do NOT setBypassDnd (Samsung may show tips for alarm-like channels)
            val ch = NotificationChannel(
                // channel ID string
                CHANNEL_ID,
                // human-readable channel name
                "Thristly Reminders",
                // importance level for the channel
                NotificationManager.IMPORTANCE_HIGH   // high so it’s visible, but not an ALARM category
            ).apply {
                // description shown in system settings for the channel
                description = "Hydration reminders"
                // remove: setBypassDnd(true)
            }
            // register the channel with the system
            nm.createNotificationChannel(ch)
        }

        // build the notification using NotificationCompat for compatibility
        val n = NotificationCompat.Builder(context, CHANNEL_ID)
            // set the small icon shown in the notification
            .setSmallIcon(R.drawable.ic_stat_thristly)
            // set the notification title
            .setContentTitle(title)
            // set the notification text/body
            .setContentText(body)
            // auto-cancel the notification when tapped
            .setAutoCancel(true)
            // set priority for compatibility on older Android versions
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            // categorize the notification as a reminder (not an alarm)
            .setCategory(NotificationCompat.CATEGORY_REMINDER) // <-- not ALARM
            // build the final Notification object
            .build()

        // post the notification with a semi-unique ID based on current time
        nm.notify(((System.currentTimeMillis() / 1000) % Int.MAX_VALUE).toInt(), n)
    }
}
