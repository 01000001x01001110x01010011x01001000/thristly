// package declaration for the app's main Kotlin namespace
package com.example.thristly

// import for PendingIntent used to check or create intents
import android.app.PendingIntent
// import for Context used throughout to access system services
import android.content.Context
// import for Intent used to start activities and broadcasts
import android.content.Intent
// import for Uri used to build package URIs
import android.net.Uri
// import for Build to check Android SDK version
import android.os.Build
// import for PowerManager to query battery optimization state
import android.os.PowerManager
// import for Settings to open battery optimization request intent
import android.provider.Settings
// import for NonNull annotation on overridden method parameter
import androidx.annotation.NonNull
// import for FlutterActivity to embed Flutter in Android activity
import io.flutter.embedding.android.FlutterActivity
// import for FlutterEngine to configure method channels
import io.flutter.embedding.engine.FlutterEngine
// import for MethodChannel to communicate with Flutter Dart code
import io.flutter.plugin.common.MethodChannel

// MainActivity extends FlutterActivity to host the Flutter app
class MainActivity : FlutterActivity() {
    // constant channel name used for Flutter <-> native method calls
    private val CHANNEL = "thristify/native_exact"

    // override to configure the Flutter engine and set up method channel handlers
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        // call superclass implementation first
        super.configureFlutterEngine(flutterEngine)
        // create a MethodChannel using the Dart executor's binary messenger
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            // set a handler to respond to method calls from Dart
            .setMethodCallHandler { call, result ->
                // switch on the method name from Dart
                when (call.method) {
                    // handle Android 13+ notifications permission request
                    "requestPostNotificationsIfNeeded" -> {
                        // if running on Android 13 (SDK 33) or newer
                        if (Build.VERSION.SDK_INT >= 33) {
                            // request the POST_NOTIFICATIONS runtime permission
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
                        }
                        // return success (null) to Dart
                        result.success(null)
                    }

                    // handle request to ignore battery optimizations
                    "requestIgnoreBatteryOptimizationsIfNeeded" -> {
                        // only available on Marshmallow (SDK 23) or newer
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            // obtain PowerManager system service
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            // get this app's package name
                            val pkg = packageName
                            // if the app is not already ignoring battery optimizations
                            if (!pm.isIgnoringBatteryOptimizations(pkg)) {
                                // create intent to request ignoring battery optimizations
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                // set the intent data to this package's URI
                                intent.data = Uri.parse("package:$pkg")
                                // start a new task for the intent
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                // launch the system activity to request the setting
                                startActivity(intent)
                            }
                        }
                        // return success (null) to Dart
                        result.success(null)
                    }

                    // handle request to read current scheduling status
                    "getStatus" -> result.success(getStatusMap())

                    // handle request to start scheduling reminders within a daily window
                    "scheduleWindow" -> {
                        // read minutes argument or default to 15 and ensure at least 1
                        val minutes = (call.argument<Int>("minutes") ?: 15).coerceAtLeast(1)
                        // read title argument or default string
                        val title = call.argument<String>("title") ?: "Thristly Reminder"
                        // read body argument or default string
                        val body = call.argument<String>("body") ?: "Time to hydrate!"
                        // read start hour argument or default to 9 and constrain to 0-23
                        val sh = (call.argument<Int>("startHour") ?: 9).coerceIn(0, 23)
                        // read start minute argument or default to 0 and constrain to 0-59
                        val sm = (call.argument<Int>("startMinute") ?: 0).coerceIn(0, 59)
                        // read end hour argument or default to 18 and constrain to 0-23
                        val eh = (call.argument<Int>("endHour") ?: 18).coerceIn(0, 23)
                        // read end minute argument or default to 0 and constrain to 0-59
                        val em = (call.argument<Int>("endMinute") ?: 0).coerceIn(0, 59)

                        // save preferences for scheduling to persistent storage
                        Prefs.save(applicationContext, minutes, title, body, sh, sm, eh, em)
                        // schedule the next exact alarm (uses setAlarmClock internally)
                        ExactAlarmScheduler.scheduleNext(applicationContext) // uses setAlarmClock()
                        // return a string confirmation to Dart
                        result.success("scheduled")
                    }

                    // handle request to cancel exact alarms and clear prefs
                    "cancelExact" -> {
                        // cancel any scheduled exact alarms
                        ExactAlarmScheduler.cancel(applicationContext)
                        // clear saved preferences
                        Prefs.clear(applicationContext)
                        // return a string confirmation to Dart
                        result.success("cancelled")
                    }

                    // if method is not implemented, notify Dart
                    else -> result.notImplemented()
                }
            }
    }

    // build a map of current status information to send to Dart
    private fun getStatusMap(): Map<String, Any?> {
        // load saved preferences
        val prefs = Prefs.load(applicationContext)
        // determine whether an alarm PendingIntent is currently scheduled
        val scheduled = isAlarmScheduled(applicationContext)
        // return a map containing scheduling and preference details
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

    // checks whether the PendingIntent for our ExactAlarmReceiver exists
    private fun isAlarmScheduled(ctx: Context): Boolean {
        // create an intent that targets the ExactAlarmReceiver broadcast receiver
        val intent = Intent(ctx, ExactAlarmReceiver::class.java)
        // set flags to only return existing PendingIntent and require immutability
        val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        // attempt to retrieve the existing PendingIntent without creating a new one
        val pi = PendingIntent.getBroadcast(ctx, ExactAlarmScheduler.REQ_CODE, intent, flags)
        // return true if the PendingIntent exists, false otherwise
        return pi != null
    }
}
