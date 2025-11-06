// Package declaration for the app's Kotlin namespace
package com.example.thristly

// Import BroadcastReceiver base class
import android.content.BroadcastReceiver
// Import Context used in onReceive
import android.content.Context
// Import Intent used to inspect the broadcast action
import android.content.Intent

// BroadcastReceiver that reacts to device boot and package replacement events
class BootReceiver : BroadcastReceiver() {
    // Called when a broadcast matching this receiver is delivered
    override fun onReceive(context: Context, intent: Intent) {
        // If the action indicates the device finished booting or the app was replaced
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            // Load persisted preferences; abort if they can't be loaded
            val prefs = Prefs.load(context) ?: return
            // Schedule the next exact alarm using the app's scheduler helper
            ExactAlarmScheduler.scheduleNext(context)
        }
    }
}
