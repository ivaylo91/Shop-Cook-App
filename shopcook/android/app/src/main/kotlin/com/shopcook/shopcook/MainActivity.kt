package com.shopcook.shopcook

import android.content.Intent
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
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (capture(intent)) channel?.invokeMethod("shared", null)
    }

    private fun capture(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND) return false
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return false
        pending = mapOf(
            "text" to text,
            "subject" to intent.getStringExtra(Intent.EXTRA_SUBJECT),
        )
        return true
    }
}
