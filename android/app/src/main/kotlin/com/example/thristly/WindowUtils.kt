package com.example.thristly

import java.util.Calendar

object WindowUtils {
    fun isNowInWindow(p: PrefData): Boolean {
        val now = Calendar.getInstance()
        val n = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val s = p.startHour * 60 + p.startMinute
        val e = p.endHour * 60 + p.endMinute
        return if (e >= s) {
            n in s until e
        } else {
            n >= s || n < e  // crosses midnight
        }
    }
}
