package com.example.thristly

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Calendar

object ExactAlarmScheduler {
    const val REQ_CODE = 4217

    fun scheduleNext(context: Context) {
        val prefs = Prefs.load(context) ?: return
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = computeNextTriggerMillis(prefs)
        val op = pendingIntent(context, prefs)
        val info = AlarmManager.AlarmClockInfo(triggerAt, launchAppIntent(context))
        am.setAlarmClock(info, op)  // <-- single path: no setExact*, no permission toast
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            context, REQ_CODE, Intent(context, ExactAlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)
    }

    private fun pendingIntent(context: Context, p: PrefData): PendingIntent {
        val i = Intent(context, ExactAlarmReceiver::class.java).apply {
            putExtra("minutes", p.minutes)
            putExtra("title", p.title)
            putExtra("body", p.body)
            putExtra("startHour", p.startHour)
            putExtra("startMinute", p.startMinute)
            putExtra("endHour", p.endHour)
            putExtra("endMinute", p.endMinute)
        }
        return PendingIntent.getBroadcast(
            context, REQ_CODE, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun launchAppIntent(context: Context): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        return PendingIntent.getActivity(
            context, 9999, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun computeNextTriggerMillis(p: PrefData): Long {
        val now = Calendar.getInstance()
        val sMin = p.startHour * 60 + p.startMinute
        val eMin = p.endHour * 60 + p.endMinute
        val nMin = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val crosses = eMin <= sMin
        fun inWindow(mins: Int) = if (!crosses) mins in sMin until eMin else (mins >= sMin || mins < eMin)

        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.startHour); set(Calendar.MINUTE, p.startMinute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val end = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.endHour); set(Calendar.MINUTE, p.endMinute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            if (crosses) add(Calendar.DAY_OF_MONTH, 1)
        }

        return if (inWindow(nMin)) {
            val next = now.clone() as Calendar
            next.add(Calendar.MINUTE, p.minutes)
            if (next.after(end)) {
                val nextStart = start.clone() as Calendar
                nextStart.add(Calendar.DAY_OF_MONTH, 1)
                nextStart.timeInMillis
            } else next.timeInMillis
        } else {
            val nextStart = start.clone() as Calendar
            if ((!crosses && now.after(nextStart)) || (crosses && nMin >= sMin)) {
                nextStart.add(Calendar.DAY_OF_MONTH, 1)
            }
            nextStart.timeInMillis
        }
    }
}
