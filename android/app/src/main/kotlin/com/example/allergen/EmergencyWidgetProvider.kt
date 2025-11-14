package com.example.allergen

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.os.Bundle
import android.util.Log

class EmergencyWidgetProvider : AppWidgetProvider() {
    
    companion object {
        private const val TAG = "EmergencyWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "🚨 Updating Emergency widgets: ${appWidgetIds.size}")
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
            Log.d(TAG, "🚨 Updating widget ID: $appWidgetId")
            
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "EMERGENCY_ACTION"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Get widget dimensions to determine layout
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            
            Log.d(TAG, "🚨 Widget dimensions - Width: $width, Height: $height")
            
            // Choose layout based on widget size
            // If width is significantly larger than height, use horizontal layout
            val layoutId = if (width > height * 1.5) {
                Log.d(TAG, "🚨 Using HORIZONTAL layout")
                R.layout.emergency_widget_layout_horizontal
            } else {
                Log.d(TAG, "🚨 Using SQUARE layout")
                R.layout.emergency_widget_layout
            }

            val views = RemoteViews(context.packageName, layoutId)
            
            // Set click handler for appropriate container
            val containerId = if (layoutId == R.layout.emergency_widget_layout_horizontal) {
                R.id.emergency_widget_container_horizontal
            } else {
                R.id.emergency_widget_container
            }
            
            views.setOnClickPendingIntent(containerId, pendingIntent)
            
            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "✅ Emergency widget updated successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating emergency widget: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        Log.d(TAG, "🚨 Widget size changed, updating layout...")
        // Update widget when size changes
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "🚨 Emergency widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "🚨 Emergency widget disabled")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        Log.d(TAG, "🚨 Emergency widgets deleted: ${appWidgetIds.size}")
    }
}