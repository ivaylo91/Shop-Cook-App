package com.shopcook.shopcook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import org.json.JSONArray

/**
 * Home screen widget showing the list with the most left to buy, with its
 * items ticked off by tapping them.
 *
 * Draws only what Dart has already worked out and saved (see
 * `home_widget_sync.dart`): the widget runs without Flutter, so the
 * wording, language and choice of list are all decided in the app.
 *
 * A tap on an item writes the tick straight into the app's database, with
 * no Flutter engine started for it. The database's own triggers queue the
 * change for a shared list, so it reaches the others the next time the app
 * syncs; the app reloads its lists when it comes back to the front.
 * Tapping the header opens the list.
 */
class ShoppingListWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val listId = widgetData.getString("list_id", null)
        val target = Uri.parse(
            if (listId != null) "shopcook://list/$listId" else "shopcook://lists",
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.shopping_list_widget)
            widgetData.getString("title", null)?.let {
                views.setTextViewText(R.id.widget_title, it)
            }
            widgetData.getString("empty_text", null)?.let {
                views.setTextViewText(R.id.widget_empty, it)
            }

            val open = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                target,
            )
            views.setOnClickPendingIntent(R.id.widget_header, open)
            views.setOnClickPendingIntent(R.id.widget_empty, open)

            // The rows come from ShoppingListWidgetService. The data uri is
            // unique per widget, or the launcher would reuse one adapter for
            // every widget placed.
            val adapter = Intent(context, ShoppingListWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse("shopcook://widget/$widgetId")
            }
            @Suppress("DEPRECATION")
            views.setRemoteAdapter(R.id.widget_list, adapter)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            // Each row fills in its item's id; mutable so it can.
            val toggle = Intent(context, ShoppingListWidget::class.java).apply {
                action = ACTION_TOGGLE
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            views.setPendingIntentTemplate(
                R.id.widget_list,
                PendingIntent.getBroadcast(context, widgetId, toggle, flags),
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE) {
            super.onReceive(context, intent)
            return
        }
        val id = intent.getStringExtra(EXTRA_ITEM_ID) ?: return
        val pending = goAsync()
        Thread {
            try {
                toggle(context, id)
            } finally {
                pending.finish()
            }
        }.start()
    }

    private fun toggle(context: Context, id: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = try {
            JSONArray(prefs.getString("items_json", "[]"))
        } catch (_: Exception) {
            return
        }
        var index = -1
        for (i in 0 until items.length()) {
            if (items.getJSONObject(i).optString("id") == id) index = i
        }
        if (index < 0) return
        val item = items.getJSONObject(index)
        val checked = !item.optBoolean("checked")

        if (!writeChecked(context, id, checked)) return

        item.put("checked", checked)
        val left = (prefs.getString("left", "0")?.toIntOrNull() ?: 0) + if (checked) -1 else 1
        prefs.edit()
            .putString("items_json", items.toString())
            .putString("left", left.coerceAtLeast(0).toString())
            .apply()

        // The rows (count included) only: Android applies a list refresh at
        // once, where it may hold back a redraw of the whole widget.
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ShoppingListWidget::class.java))
        manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
    }

    /**
     * Ticks or unticks [id] in the app's database. The file is the one Drift
     * opens (path_provider's documents folder is `app_flutter`). False when
     * there is no database yet or the write failed, and the widget is left
     * as it was.
     */
    private fun writeChecked(context: Context, id: String, checked: Boolean): Boolean {
        val file = File(context.getDir("flutter", Context.MODE_PRIVATE), "shopcook.sqlite")
        if (!file.exists()) return false
        return try {
            // NO_LOCALIZED_COLLATORS: otherwise Android adds its own
            // android_metadata table to a database that is not its own.
            SQLiteDatabase.openDatabase(
                file.path,
                null,
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.NO_LOCALIZED_COLLATORS,
            ).use { db ->
                val values = ContentValues().apply { put("is_checked", if (checked) 1 else 0) }
                db.update("products", values, "id = ?", arrayOf(id)) == 1
            }
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        const val ACTION_TOGGLE = "com.shopcook.shopcook.widget.TOGGLE"
        const val EXTRA_ITEM_ID = "item_id"

        /** Where home_widget keeps what Dart saves. */
        const val PREFS = "HomeWidgetPreferences"

        /**
         * "3 left", in the app's language and plural. Dart saves the line
         * for every count down to none, since a tick here changes the
         * count without the app.
         */
        fun summary(prefs: SharedPreferences): String {
            val left = prefs.getString("left", null)?.toIntOrNull()
            val summaries = try {
                JSONArray(prefs.getString("summaries", "[]"))
            } catch (_: Exception) {
                JSONArray()
            }
            if (left == null || left < 0 || left >= summaries.length()) {
                return prefs.getString("summary", null) ?: ""
            }
            return summaries.optString(left)
        }
    }
}
