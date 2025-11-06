// Package declaration for this receiver class
package com.example.thristly

// Import Android BroadcastReceiver base class
import android.content.BroadcastReceiver
// Import Android Context type
import android.content.Context
// Import Android Intent type
import android.content.Intent

// Define a BroadcastReceiver to handle exact alarms
class ExactAlarmReceiver : BroadcastReceiver() {
    // Indicate this method overrides the base class implementation
    override fun onReceive(context: Context, intent: Intent) {
        // Load saved preferences/state using a helper
        val prefs = Prefs.load(context)
        // If preferences exist and the current time is within the allowed window
        if (prefs != null && WindowUtils.isNowInWindow(prefs)) {
            // Show a notification using the stored title and body
            NotificationUtils.show(context, prefs.title, prefs.body)
        }
        // Schedule the next exact alarm after handling this one
        ExactAlarmScheduler.scheduleNext(context)
    }
}
