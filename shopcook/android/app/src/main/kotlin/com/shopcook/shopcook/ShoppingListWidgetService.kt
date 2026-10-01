package com.shopcook.shopcook

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

/**
 * Supplies the home screen widget's rows: first the count ("3 left to
 * buy"), then the items Dart saved as `items_json`, each
 * `{id, text, checked}`. A row with no id ("+3 more") is shown but does
 * nothing when tapped.
 */
class ShoppingListWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        Rows(applicationContext)

    private class Rows(private val context: Context) : RemoteViewsFactory {
        private var items: List<JSONObject> = emptyList()
        private var summary = ""

        override fun onCreate() {}

        override fun onDataSetChanged() {
            val prefs = context.getSharedPreferences(
                ShoppingListWidget.PREFS,
                Context.MODE_PRIVATE,
            )
            summary = ShoppingListWidget.summary(prefs)
            items = try {
                val array = JSONArray(prefs.getString("items_json", "[]"))
                List(array.length()) { array.getJSONObject(it) }
            } catch (_: Exception) {
                emptyList()
            }
        }

        override fun onDestroy() {}

        /** The count row, when there is a count to show. */
        private val lead get() = if (summary.isEmpty() || items.isEmpty()) 0 else 1

        override fun getCount() = lead + items.size

        override fun getViewAt(position: Int): RemoteViews {
            if (position < lead) {
                return RemoteViews(context.packageName, R.layout.shopping_list_widget_summary)
                    .apply { setTextViewText(R.id.widget_summary_row, summary) }
            }
            val item = items.getOrNull(position - lead)
            val views = RemoteViews(context.packageName, R.layout.shopping_list_widget_item)
            if (item == null) return views

            val id = item.optString("id")
            val checked = item.optBoolean("checked")
            views.setTextViewText(R.id.widget_item_text, item.optString("text"))

            if (id.isEmpty()) {
                // The "+3 more" line: no box, muted.
                views.setViewVisibility(R.id.widget_item_box, android.view.View.INVISIBLE)
                views.setTextColor(R.id.widget_item_text, context.getColor(R.color.widget_ink_muted))
                return views
            }

            views.setViewVisibility(R.id.widget_item_box, android.view.View.VISIBLE)
            views.setImageViewResource(
                R.id.widget_item_box,
                if (checked) R.drawable.ic_widget_checked else R.drawable.ic_widget_unchecked,
            )
            views.setTextColor(
                R.id.widget_item_text,
                context.getColor(if (checked) R.color.widget_ink_muted else R.color.widget_ink),
            )
            views.setInt(
                R.id.widget_item_text,
                "setPaintFlags",
                Paint.ANTI_ALIAS_FLAG or if (checked) Paint.STRIKE_THRU_TEXT_FLAG else 0,
            )
            views.setOnClickFillInIntent(
                R.id.widget_item,
                Intent().putExtra(ShoppingListWidget.EXTRA_ITEM_ID, id),
            )
            return views
        }

        override fun getLoadingView(): RemoteViews? = null

        override fun getViewTypeCount() = 2

        override fun getItemId(position: Int) = position.toLong()

        override fun hasStableIds() = false
    }
}
