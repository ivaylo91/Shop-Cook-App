package com.shopcook.shopcook

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared from other apps (a recipe link from a browser, a
 * list from a notes app) and hands it to Dart over the `shopcook/share`
 * channel.
 *
 * Written by hand rather than with a plugin: the maintained sharing plugin
 * needs AGP 9 and Kotlin 2.4, which this project is deliberately not on,
 * and plain text is all the app accepts.
 *
 * Dart pulls the share with `takeShared` rather than having it pushed, so a
 * share that starts the app is not lost while Flutter is still booting.
 * `shared` is only a nudge to pull again when the app was already running.
 *
 * Invite links to a shared list arrive the same way: the join page's
 * button opens `shopcook://join/CODE`, which is handed over as `join`
 * rather than `text`.
 */
class MainActivity : FlutterActivity() {
    private var pending: Map<String, String?>? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shopcook/share",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeShared" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A restored activity would otherwise replay the share it was
        // started with.
        if (savedInstanceState == null) capture(intent)
        createNotificationChannel()
    }

    /**
     * The channel notifications about shared lists arrive on. Android shows
     * its name in the app's notification settings, and without it they would
     * land on Firebase's catch-all "Miscellaneous". Creating a channel that
     * already exists does nothing, so this runs on every start.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "shared_lists",
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = getString(R.string.notification_channel_description)
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (capture(intent)) channel?.invokeMethod("shared", null)
    }

    private fun capture(intent: Intent?): Boolean {
        val data = intent?.data
        if (intent?.action == Intent.ACTION_VIEW &&
            data?.scheme == "shopcook" &&
            data.host == "join"
        ) {
            val code = data.lastPathSegment ?: return false
            pending = mapOf("join" to code)
            return true
        }
        if (intent?.action != Intent.ACTION_SEND) return false
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return false
        pending = mapOf(
            "text" to text,
            "subject" to intent.getStringExtra(Intent.EXTRA_SUBJECT),
        )
        return true
    }
}
