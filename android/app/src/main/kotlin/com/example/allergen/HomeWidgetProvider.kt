package com.example.allergen

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.*
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.min

class HomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.air_quality_widget).apply {
                // Get data from shared preferences
                val aqi = widgetData.getInt("aqi", 0)
                val qualityLevel = widgetData.getString("quality_level", "Loading...")
                val dominantPollutant = widgetData.getString("dominant_pollutant", "N/A")
                val location = widgetData.getString("location", "Unknown Location")

                // Update text views
                setTextViewText(R.id.aqi_value, if (aqi > 0) aqi.toString() else "--")
                setTextViewText(R.id.quality_level, qualityLevel)
                setTextViewText(R.id.dominant_pollutant, "Dominant: $dominantPollutant")
                setTextViewText(R.id.location, location)

                // Generate and set gauge bitmap
                val gaugeBitmap = createGaugeBitmap(context, aqi)
                setImageViewBitmap(R.id.gauge_image, gaugeBitmap)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun createGaugeBitmap(context: Context, aqi: Int): Bitmap {
        val size = (100 * context.resources.displayMetrics.density).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val strokeWidth = size * 0.14f
        val radius = (size - strokeWidth) / 2
        val centerX = size / 2f
        val centerY = size / 2f

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth
        }

        val rectF = RectF(
            centerX - radius,
            centerY - radius,
            centerX + radius,
            centerY + radius
        )

        // Draw background arc (light gray)
        paint.color = Color.parseColor("#E0E0E0")
        paint.strokeCap = Paint.Cap.ROUND
        canvas.drawArc(rectF, 135f, 270f, false, paint)

        // Draw colored gradient arc with segments
        if (aqi > 0) {
            val normalizedAqi = min(aqi.toFloat(), 500f)
            val progress = normalizedAqi / 500f
            val totalSweepAngle = 270f
            val sweepAngle = progress * totalSweepAngle

            // Number of segments for smooth gradient
            val segments = 100
            val segmentAngle = sweepAngle / segments

            for (i in 0..segments) {
                val segmentProgress = i.toFloat() / segments
                val aqiAtProgress = segmentProgress * normalizedAqi

                // Get color for this segment
                paint.color = getColorForAqi(aqiAtProgress)
                
                // Set stroke cap for smooth gradient
                paint.strokeCap = when {
                    i == 0 -> Paint.Cap.ROUND // Round start
                    i == segments -> Paint.Cap.ROUND // Round end
                    else -> Paint.Cap.BUTT // Butt for middle segments to avoid gaps
                }

                canvas.drawArc(
                    rectF,
                    135f + (i * segmentAngle),
                    segmentAngle,
                    false,
                    paint
                )
            }
        }

        return bitmap
    }

    private fun getColorForAqi(aqiValue: Float): Int {
        return when {
            aqiValue <= 100 -> {
                // Green to Light Green
                lerpColor(
                    Color.parseColor("#00E400"),
                    Color.parseColor("#A8D96E"),
                    aqiValue / 100f
                )
            }
            aqiValue <= 150 -> {
                // Light Green to Yellow
                lerpColor(
                    Color.parseColor("#A8D96E"),
                    Color.parseColor("#FFFF00"),
                    (aqiValue - 100f) / 50f
                )
            }
            aqiValue <= 200 -> {
                // Yellow to Orange
                lerpColor(
                    Color.parseColor("#FFFF00"),
                    Color.parseColor("#FF7E00"),
                    (aqiValue - 150f) / 50f
                )
            }
            aqiValue <= 300 -> {
                // Orange to Red
                lerpColor(
                    Color.parseColor("#FF7E00"),
                    Color.parseColor("#FF0000"),
                    (aqiValue - 200f) / 100f
                )
            }
            aqiValue <= 400 -> {
                // Red to Dark Red
                lerpColor(
                    Color.parseColor("#FF0000"),
                    Color.parseColor("#990000"),
                    (aqiValue - 300f) / 100f
                )
            }
            else -> {
                // Dark Red
                Color.parseColor("#990000")
            }
        }
    }

    private fun lerpColor(startColor: Int, endColor: Int, fraction: Float): Int {
        val clampedFraction = fraction.coerceIn(0f, 1f)
        
        val startA = Color.alpha(startColor)
        val startR = Color.red(startColor)
        val startG = Color.green(startColor)
        val startB = Color.blue(startColor)

        val endA = Color.alpha(endColor)
        val endR = Color.red(endColor)
        val endG = Color.green(endColor)
        val endB = Color.blue(endColor)

        val a = (startA + clampedFraction * (endA - startA)).toInt()
        val r = (startR + clampedFraction * (endR - startR)).toInt()
        val g = (startG + clampedFraction * (endG - startG)).toInt()
        val b = (startB + clampedFraction * (endB - startB)).toInt()

        return Color.argb(a, r, g, b)
    }
}