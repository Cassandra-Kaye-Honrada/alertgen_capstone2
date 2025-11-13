// android/app/src/main/kotlin/com/example/allergen/AirQualityWidgetProvider.kt
package com.example.allergen

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.util.Log

class AirQualityWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "AirQualityWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "🌤️ Updating Air Quality widgets: ${appWidgetIds.size}")
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            Log.d(TAG, "🌤️ Updating widget ID: $appWidgetId")
            
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "AIR_QUALITY_ACTION"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                2, // Unique request code
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val views = RemoteViews(context.packageName, R.layout.air_quality_widget_layout)
            views.setOnClickPendingIntent(R.id.air_quality_widget_container, pendingIntent)
            
            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "✅ Air Quality widget updated successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating air quality widget: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "🌤️ Air Quality widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "🌤️ Air Quality widget disabled")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        Log.d(TAG, "🌤️ Air Quality widgets deleted: ${appWidgetIds.size}")
    }
}