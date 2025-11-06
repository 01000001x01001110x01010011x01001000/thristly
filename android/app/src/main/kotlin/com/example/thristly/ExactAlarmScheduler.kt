// package declaration for this Kotlin file
package com.example.thristly

// import Android AlarmManager class
import android.app.AlarmManager
// import Android PendingIntent class
import android.app.PendingIntent
// import Android Context class
import android.content.Context
// import Android Intent class
import android.content.Intent
// import Java Calendar utility
import java.util.Calendar

// define a singleton object for scheduling exact alarms
object ExactAlarmScheduler {
    // constant request code used for PendingIntents
    const val REQ_CODE = 4217

    // schedule the next alarm based on stored preferences
    fun scheduleNext(context: Context) {
        // load preferences, return early if none
        val prefs = Prefs.load(context) ?: return
        // get the AlarmManager system service
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // compute the next trigger time in milliseconds
        val triggerAt = computeNextTriggerMillis(prefs)
        // create the PendingIntent that will be fired when the alarm goes off
        val op = pendingIntent(context, prefs)
        // create an AlarmClockInfo with the trigger time and an intent to launch the app
        val info = AlarmManager.AlarmClockInfo(triggerAt, launchAppIntent(context))
        // set the alarm as an alarm clock (single path; no setExact* used)
        am.setAlarmClock(info, op)  // <-- single path: no setExact*, no permission toast
    }

    // cancel any scheduled alarm
    fun cancel(context: Context) {
        // get the AlarmManager system service
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // build a PendingIntent matching the one used to schedule the alarm
        val pi = PendingIntent.getBroadcast(
            context, REQ_CODE, Intent(context, ExactAlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // cancel the alarm associated with this PendingIntent
        am.cancel(pi)
    }

    // create the PendingIntent that triggers the ExactAlarmReceiver with preference extras
    private fun pendingIntent(context: Context, p: PrefData): PendingIntent {
        // build an Intent targeting the ExactAlarmReceiver and attach extras from prefs
        val i = Intent(context, ExactAlarmReceiver::class.java).apply {
            putExtra("minutes", p.minutes)
            putExtra("title", p.title)
            putExtra("body", p.body)
            putExtra("startHour", p.startHour)
            putExtra("startMinute", p.startMinute)
            putExtra("endHour", p.endHour)
            putExtra("endMinute", p.endMinute)
        }
        // return a broadcast PendingIntent with update and immutable flags
        return PendingIntent.getBroadcast(
            context, REQ_CODE, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // create a PendingIntent that launches the app (used for AlarmClockInfo)
    private fun launchAppIntent(context: Context): PendingIntent {
        // try to get the launch intent for the package, fallback to MainActivity intent
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        // add flags to start a new task and reset task if needed
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        // return an activity PendingIntent with update and immutable flags
        return PendingIntent.getActivity(
            context, 9999, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // compute the next trigger time in milliseconds given the preference window and interval
    private fun computeNextTriggerMillis(p: PrefData): Long {
        // get the current time as a Calendar instance
        val now = Calendar.getInstance()
        // compute start time in minutes from midnight
        val sMin = p.startHour * 60 + p.startMinute
        // compute end time in minutes from midnight
        val eMin = p.endHour * 60 + p.endMinute
        // compute current time in minutes from midnight
        val nMin = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        // determine if the time window crosses midnight
        val crosses = eMin <= sMin
        // helper function to check if a minutes value is inside the allowed window
        fun inWindow(mins: Int) = if (!crosses) mins in sMin until eMin else (mins >= sMin || mins < eMin)

        // build a Calendar for the start time today
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.startHour); set(Calendar.MINUTE, p.startMinute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        // build a Calendar for the end time (may be tomorrow if window crosses midnight)
        val end = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.endHour); set(Calendar.MINUTE, p.endMinute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            if (crosses) add(Calendar.DAY_OF_MONTH, 1)
        }

        // if now is inside the allowed window
        return if (inWindow(nMin)) {
            // clone now and add the configured minutes interval
            val next = now.clone() as Calendar
            next.add(Calendar.MINUTE, p.minutes)
            // if the computed next time is after the window end, schedule at next day's start
            if (next.after(end)) {
                val nextStart = start.clone() as Calendar
                nextStart.add(Calendar.DAY_OF_MONTH, 1)
                nextStart.timeInMillis
            } else next.timeInMillis
        } else {
            // if now is outside the window, compute the next start time
            val nextStart = start.clone() as Calendar
            // if start is earlier than now (or certain crossing cases), move start to the next day
            if ((!crosses && now.after(nextStart)) || (crosses && nMin >= sMin)) {
                nextStart.add(Calendar.DAY_OF_MONTH, 1)
            }
            // return the start time in milliseconds
            nextStart.timeInMillis
        }
    }
}
