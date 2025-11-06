// Package declaration for this Kotlin file
package com.example.thristly

// Import Calendar for obtaining current hour and minute
import java.util.Calendar

// Singleton object providing window-related utility functions
object WindowUtils {
    // Check if the current time falls within the provided preference window
    fun isNowInWindow(p: PrefData): Boolean {
        // Get the current date/time as a Calendar instance
        val now = Calendar.getInstance()
        // Calculate current time in minutes since midnight
        val n = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        // Calculate window start time in minutes since midnight
        val s = p.startHour * 60 + p.startMinute
        // Calculate window end time in minutes since midnight
        val e = p.endHour * 60 + p.endMinute
        // If end is after or equal to start, the window does not cross midnight
        return if (e >= s) {
            // Return true if current minutes are within [start, end)
            n in s until e
        } else {
            // If window crosses midnight, return true if now is after start or before end
            n >= s || n < e  // crosses midnight
        }
    } // end of isNowInWindow
} // end of WindowUtils
