// Package declaration for this Kotlin file
package com.example.thristly

// Import Android Context used for SharedPreferences
import android.content.Context

// Data class representing saved preferences
data class PrefData(
    // Number of minutes between reminders
    val minutes: Int,
    // Notification title text
    val title: String,
    // Notification body text
    val body: String,
    // Allowed start hour for notifications
    val startHour: Int,
    // Allowed start minute for notifications
    val startMinute: Int,
    // Allowed end hour for notifications
    val endHour: Int,
    // Allowed end minute for notifications
    val endMinute: Int
)

// Singleton object to manage preference persistence
object Prefs {
    // Name of the SharedPreferences file
    private const val NAME = "thristly_prefs"

    // Save provided values into SharedPreferences
    fun save(ctx: Context, minutes: Int, title: String, body: String,
             sh: Int, sm: Int, eh: Int, em: Int) {
        // Get SharedPreferences editor
        val e = ctx.getSharedPreferences(NAME, Context.MODE_PRIVATE).edit()
        // Store minutes as int
        e.putInt("minutes", minutes)
        // Store title as string
        e.putString("title", title)
        // Store body as string
        e.putString("body", body)
        // Store start hour as int
        e.putInt("startHour", sh)
        // Store start minute as int
        e.putInt("startMinute", sm)
        // Store end hour as int
        e.putInt("endHour", eh)
        // Store end minute as int
        e.putInt("endMinute", em)
        // Apply changes asynchronously
        e.apply()
    }

    // Load preferences and return PrefData or null if missing/invalid
    fun load(ctx: Context): PrefData? {
        // Get SharedPreferences instance
        val p = ctx.getSharedPreferences(NAME, Context.MODE_PRIVATE)
        // Read minutes, default to -1 if absent
        val minutes = p.getInt("minutes", -1)
        // If minutes not set or non-positive, treat as absent
        if (minutes <= 0) return null
        // Read title or return null if missing
        val title = p.getString("title", null) ?: return null
        // Read body or return null if missing
        val body = p.getString("body", null) ?: return null
        // Ensure start and end hour keys exist
        if (!p.contains("startHour") || !p.contains("endHour")) return null
        // Construct and return PrefData with defaults for minutes if needed
        return PrefData(
            minutes,
            title,
            body,
            // Default start hour to 9 if missing
            p.getInt("startHour", 9),
            // Default start minute to 0 if missing
            p.getInt("startMinute", 0),
            // Default end hour to 18 if missing
            p.getInt("endHour", 18),
            // Default end minute to 0 if missing
            p.getInt("endMinute", 0)
        )
    }

    // Clear all saved preferences
    fun clear(ctx: Context) {
        // Clear and apply changes on the SharedPreferences editor
        ctx.getSharedPreferences(NAME, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
