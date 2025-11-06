package com.example.thristly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ExactAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = Prefs.load(context)
        if (prefs != null && WindowUtils.isNowInWindow(prefs)) {
            NotificationUtils.show(context, prefs.title, prefs.body)
        }
        ExactAlarmScheduler.scheduleNext(context)
    }
}
