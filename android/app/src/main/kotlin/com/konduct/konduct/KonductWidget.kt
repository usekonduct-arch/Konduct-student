package com.konduct.konduct

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen widget. The app writes what it shows (lib/app/home_widget_sync.dart): a title,
 * an optional big value, a line under it, and a button with the link it opens. Tapping anywhere
 * else opens the app.
 */
class KonductWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.konduct_widget).apply {
                setTextViewText(R.id.widget_title, widgetData.getString("title", null) ?: "Konduct")
                val value = widgetData.getString("value", null) ?: ""
                setTextViewText(R.id.widget_value, value)
                setViewVisibility(R.id.widget_value, if (value.isEmpty()) View.GONE else View.VISIBLE)
                setTextViewText(R.id.widget_subtitle, widgetData.getString("subtitle", null) ?: context.getString(R.string.widget_subtitle))
                setTextViewText(R.id.widget_button, widgetData.getString("button", null) ?: context.getString(R.string.widget_button))
                val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("konduct-widget://open"))
                setOnClickPendingIntent(R.id.widget_root, open)
                val link = widgetData.getString("buttonLink", null) ?: context.getString(R.string.widget_button_link)
                setOnClickPendingIntent(R.id.widget_button, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link)))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
