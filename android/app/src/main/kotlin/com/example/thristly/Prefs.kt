package com.example.thristly

import android.content.Context

data class PrefData(
    val minutes: Int,
    val title: String,
    val body: String,
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int
)

object Prefs {
    private const val NAME = "thristly_prefs"

    fun save(ctx: Context, minutes: Int, title: String, body: String,
             sh: Int, sm: Int, eh: Int, em: Int) {
        val e = ctx.getSharedPreferences(NAME, Context.MODE_PRIVATE).edit()
        e.putInt("minutes", minutes)
        e.putString("title", title)
        e.putString("body", body)
        e.putInt("startHour", sh)
        e.putInt("startMinute", sm)
        e.putInt("endHour", eh)
        e.putInt("endMinute", em)
        e.apply()
    }

    fun load(ctx: Context): PrefData? {
        val p = ctx.getSharedPreferences(NAME, Context.MODE_PRIVATE)
        val minutes = p.getInt("minutes", -1)
        if (minutes <= 0) return null
        val title = p.getString("title", null) ?: return null
        val body = p.getString("body", null) ?: return null
        if (!p.contains("startHour") || !p.contains("endHour")) return null
        return PrefData(
            minutes,
            title,
            body,
            p.getInt("startHour", 9),
            p.getInt("startMinute", 0),
            p.getInt("endHour", 18),
            p.getInt("endMinute", 0)
        )
    }

    fun clear(ctx: Context) {
        ctx.getSharedPreferences(NAME, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
