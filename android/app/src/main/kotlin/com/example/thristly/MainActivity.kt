package com.example.thristly

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "thristify/native_exact"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Android 13+ notifications permission
                    "requestPostNotificationsIfNeeded" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
                        }
                        result.success(null)
                    }

                    // Ask to ignore battery optimizations (helps delivery on many OEMs)
                    "requestIgnoreBatteryOptimizationsIfNeeded" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            val pkg = packageName
                            if (!pm.isIgnoringBatteryOptimizations(pkg)) {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                intent.data = Uri.parse("package:$pkg")
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                            }
                        }
                        result.success(null)
                    }

                    // Read current state
                    "getStatus" -> result.success(getStatusMap())

                    // Start scheduling within a daily window (no exact-alarm permission gating)
                    "scheduleWindow" -> {
                        val minutes = (call.argument<Int>("minutes") ?: 15).coerceAtLeast(1)
                        val title = call.argument<String>("title") ?: "Thristly Reminder"
                        val body = call.argument<String>("body") ?: "Time to hydrate!"
                        val sh = (call.argument<Int>("startHour") ?: 9).coerceIn(0, 23)
                        val sm = (call.argument<Int>("startMinute") ?: 0).coerceIn(0, 59)
                        val eh = (call.argument<Int>("endHour") ?: 18).coerceIn(0, 23)
                        val em = (call.argument<Int>("endMinute") ?: 0).coerceIn(0, 59)

                        Prefs.save(applicationContext, minutes, title, body, sh, sm, eh, em)
                        ExactAlarmScheduler.scheduleNext(applicationContext) // uses setAlarmClock()
                        result.success("scheduled")
                    }

                    // Stop everything
                    "cancelExact" -> {
                        ExactAlarmScheduler.cancel(applicationContext)
                        Prefs.clear(applicationContext)
                        result.success("cancelled")
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun getStatusMap(): Map<String, Any?> {
        val prefs = Prefs.load(applicationContext)
        val scheduled = isAlarmScheduled(applicationContext)
        return mapOf(
            "scheduled" to scheduled,
            "minutes" to (prefs?.minutes ?: 0),
            "title" to (prefs?.title ?: ""),
            "body" to (prefs?.body ?: ""),
            "startHour" to (prefs?.startHour ?: 0),
            "startMinute" to (prefs?.startMinute ?: 0),
            "endHour" to (prefs?.endHour ?: 0),
            "endMinute" to (prefs?.endMinute ?: 0),
        )
    }

    // Detects if our PendingIntent exists
    private fun isAlarmScheduled(ctx: Context): Boolean {
        val intent = Intent(ctx, ExactAlarmReceiver::class.java)
        val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        val pi = PendingIntent.getBroadcast(ctx, ExactAlarmScheduler.REQ_CODE, intent, flags)
        return pi != null
    }
}
