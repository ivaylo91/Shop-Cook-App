package com.shopcook.shopcook

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget showing the list with the most left to buy.
 *
 * Draws only what Dart has already worked out and saved (see
 * `home_widget_sync.dart`): the widget runs without Flutter, so the
 * wording, language and choice of list are all decided in the app.
 * Tapping it opens that list.
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
            views.setTextViewText(
                R.id.widget_summary,
                widgetData.getString("summary", null) ?: "",
            )
            widgetData.getString("items", null)?.let {
                views.setTextViewText(R.id.widget_items, it)
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, target),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
