package com.example.allergen

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.os.Bundle
import android.util.Log

class ScanWidgetProvider : AppWidgetProvider() {
    
    companion object {
        private const val TAG = "ScanWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "📷 Updating Scan widgets: ${appWidgetIds.size}")
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
            Log.d(TAG, "📷 Updating widget ID: $appWidgetId")
            
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "SCAN_ACTION"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                1,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Get widget dimensions to determine layout
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            
            Log.d(TAG, "📷 Widget dimensions - Width: $width, Height: $height")
            
            // Choose layout based on widget size
            // If width is significantly larger than height, use horizontal layout
            val layoutId = if (width > height * 1.5) {
                Log.d(TAG, "📷 Using HORIZONTAL layout")
                R.layout.scan_widget_layout_horizontal
            } else {
                Log.d(TAG, "📷 Using SQUARE layout")
                R.layout.scan_widget_layout
            }

            val views = RemoteViews(context.packageName, layoutId)
            
            // Set click handler for appropriate container
            val containerId = if (layoutId == R.layout.scan_widget_layout_horizontal) {
                R.id.scan_widget_container_horizontal
            } else {
                R.id.scan_widget_container
            }
            
            views.setOnClickPendingIntent(containerId, pendingIntent)
            
            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "✅ Scan widget updated successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating scan widget: ${e.message}")
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
        Log.d(TAG, "📷 Widget size changed, updating layout...")
        // Update widget when size changes
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "📷 Scan widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "📷 Scan widget disabled")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        Log.d(TAG, "📷 Scan widgets deleted: ${appWidgetIds.size}")
    }
}

