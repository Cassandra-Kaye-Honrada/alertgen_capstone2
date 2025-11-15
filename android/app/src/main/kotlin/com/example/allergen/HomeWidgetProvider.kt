package com.example.allergen

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.*
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.util.Log
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetProvider
import kotlinx.coroutines.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.min

class HomeWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "HomeWidgetProvider"
        private const val API_KEY = "AIzaSyCWva81wgqeq5qIShLvoO9hs20ejk73gCE"
        private const val DEFAULT_LATITUDE = 28.6448
        private const val DEFAULT_LONGITUDE = 77.2169
        private const val ACTION_REFRESH = "com.example.allergen.ACTION_REFRESH_WIDGET"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "onUpdate called - Updating widgets: ${appWidgetIds.size}")
        Log.d(TAG, "Time: ${getCurrentTime()}")
        Log.d(TAG, "========================================")
        
        appWidgetIds.forEach { widgetId ->
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        
        context?.let { ctx ->
            when (intent?.action) {
                ACTION_REFRESH -> {
                    Log.d(TAG, "========================================")
                    Log.d(TAG, "REFRESH BUTTON CLICKED!")
                    Log.d(TAG, "Time: ${getCurrentTime()}")
                    Log.d(TAG, "========================================")
                    
                    val appWidgetManager = AppWidgetManager.getInstance(ctx)
                    val widgetIds = appWidgetManager.getAppWidgetIds(
                        android.content.ComponentName(ctx, HomeWidgetProvider::class.java)
                    )
                    
                    widgetIds.forEach { widgetId ->
                        updateWidget(ctx, appWidgetManager, widgetId)
                    }
                }
                AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                    Log.d(TAG, "Widget update action received")
                    val appWidgetManager = AppWidgetManager.getInstance(ctx)
                    val widgetIds = appWidgetManager.getAppWidgetIds(
                        android.content.ComponentName(ctx, HomeWidgetProvider::class.java)
                    )
                    widgetIds.forEach { widgetId ->
                        updateWidget(ctx, appWidgetManager, widgetId)
                    }
                }
            }
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        try {
            Log.d(TAG, "updateWidget started for widget ID: $widgetId")
            
            // Show loading state immediately
            showLoadingState(context, appWidgetManager, widgetId)
            
            // Fetch data asynchronously
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    Log.d(TAG, "Starting async data fetch...")
                    
                    val location = getLocation(context)
                    val (latitude, longitude, locationName) = if (location != null) {
                        Log.d(TAG, "✓ Using actual location: ${location.latitude}, ${location.longitude}")
                        Triple(
                            location.latitude,
                            location.longitude,
                            getLocationName(context, location.latitude, location.longitude)
                        )
                    } else {
                        Log.d(TAG, "✗ Using default location (permissions not granted)")
                        Triple(DEFAULT_LATITUDE, DEFAULT_LONGITUDE, "Default Location")
                    }
                    
                    Log.d(TAG, "Fetching air quality data...")
                    val airQualityData = fetchAirQuality(latitude, longitude)
                    
                    Log.d(TAG, "Data fetched, updating UI on main thread...")
                    withContext(Dispatchers.Main) {
                        updateWidgetWithData(
                            context,
                            appWidgetManager,
                            widgetId,
                            airQualityData,
                            locationName
                        )
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "✗✗✗ Error in async fetch: ${e.message}")
                    e.printStackTrace()
                    withContext(Dispatchers.Main) {
                        updateWidgetWithError(context, appWidgetManager, widgetId)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "✗✗✗ Error in updateWidget: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun showLoadingState(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        Log.d(TAG, "Showing loading state at ${getCurrentTime()}")
        val views = RemoteViews(context.packageName, R.layout.air_quality_widget).apply {
            setTextViewText(R.id.aqi_value, "--")
            setTextViewText(R.id.quality_level, "Loading...")
            setTextViewText(R.id.dominant_pollutant, "Fetching...")
            setTextViewText(R.id.location, "Please wait")
            
            val loadingBitmap = createGaugeBitmap(context, 0)
            setImageViewBitmap(R.id.gauge_image, loadingBitmap)
            
            setupClickHandlers(this, context, widgetId)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun updateWidgetWithData(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        data: AirQualityResult,
        locationName: String
    ) {
        val currentTime = getCurrentTime()
        val randomNumber = (0..999).random()
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "✓✓✓ WIDGET UPDATE WITH FRESH DATA!")
        Log.d(TAG, "Time: $currentTime")
        Log.d(TAG, "Random Test Number: $randomNumber")
        Log.d(TAG, "AQI: ${data.aqi}")
        Log.d(TAG, "Category: ${data.category}")
        Log.d(TAG, "Pollutant: ${data.dominantPollutant}")
        Log.d(TAG, "Location: $locationName")
        Log.d(TAG, "========================================")
        
        val views = RemoteViews(context.packageName, R.layout.air_quality_widget).apply {
            // Show AQI value
            setTextViewText(R.id.aqi_value, if (data.aqi > 0) data.aqi.toString() else "--")
            
            // Show category WITH timestamp for visual confirmation
            setTextViewText(R.id.quality_level, "${data.category} [$currentTime]")
            
            // Show random number in pollutant field to prove it's updating
            setTextViewText(R.id.dominant_pollutant, "Test: $randomNumber - ${data.dominantPollutant}")
            
            // Show location
            setTextViewText(R.id.location, locationName)
            
            // Update gauge
            val gaugeBitmap = createGaugeBitmap(context, data.aqi)
            setImageViewBitmap(R.id.gauge_image, gaugeBitmap)
            
            setupClickHandlers(this, context, widgetId)
        }
        
        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "✓ Widget UI updated successfully!")
    }

    private fun updateWidgetWithError(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        Log.e(TAG, "Showing error state at ${getCurrentTime()}")
        val views = RemoteViews(context.packageName, R.layout.air_quality_widget).apply {
            setTextViewText(R.id.aqi_value, "!")
            setTextViewText(R.id.quality_level, "Error")
            setTextViewText(R.id.dominant_pollutant, "Tap to retry")
            setTextViewText(R.id.location, "Check connection [${getCurrentTime()}]")
            
            val errorBitmap = createGaugeBitmap(context, 0)
            setImageViewBitmap(R.id.gauge_image, errorBitmap)
            
            setupClickHandlers(this, context, widgetId)
        }
        
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun setupClickHandlers(
        views: RemoteViews,
        context: Context,
        widgetId: Int
    ) {
        // Refresh button click
        val refreshIntent = Intent(context, HomeWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            widgetId + 1000,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

        // Widget body click - open app
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = android.net.Uri.parse("alertgen://airquality")
            putExtra("navigate_to_air_quality", true)
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context,
            widgetId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, mainPendingIntent)
    }

    private fun getLocation(context: Context): Location? {
        try {
            Log.d(TAG, "Checking location permissions...")
            if (ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.e(TAG, "✗ Location permissions not granted")
                return null
            }

            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            
            val location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                ?: locationManager.getLastKnownLocation(LocationManager.PASSIVE_PROVIDER)
            
            if (location != null) {
                Log.d(TAG, "✓ Location found: ${location.latitude}, ${location.longitude}")
            } else {
                Log.d(TAG, "✗ No location available")
            }
            
            return location
        } catch (e: Exception) {
            Log.e(TAG, "✗ Error getting location: ${e.message}")
            return null
        }
    }

    private fun getLocationName(context: Context, latitude: Double, longitude: Double): String {
        return try {
            val geocoder = Geocoder(context, Locale.getDefault())
            val addresses = geocoder.getFromLocation(latitude, longitude, 1)
            if (addresses != null && addresses.isNotEmpty()) {
                addresses[0].locality ?: addresses[0].subAdminArea ?: "Current Location"
            } else {
                "Current Location"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting location name: ${e.message}")
            "Current Location"
        }
    }

    private fun fetchAirQuality(latitude: Double, longitude: Double): AirQualityResult {
        val timestamp = System.currentTimeMillis()
        Log.d(TAG, "========================================")
        Log.d(TAG, ">>> FETCHING AIR QUALITY API <<<")
        Log.d(TAG, "Timestamp: $timestamp")
        Log.d(TAG, "Time: ${getCurrentTime()}")
        Log.d(TAG, "Location: $latitude, $longitude")
        Log.d(TAG, "========================================")
        
        // Add timestamp to URL to prevent caching
        val url = URL("https://airquality.googleapis.com/v1/currentConditions:lookup?key=$API_KEY&t=$timestamp")
        val connection = url.openConnection() as HttpURLConnection
        
        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Cache-Control", "no-cache")
            connection.doOutput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            val requestBody = """
                {
                    "location": {
                        "latitude": $latitude,
                        "longitude": $longitude
                    },
                    "extraComputations": [
                        "HEALTH_RECOMMENDATIONS",
                        "DOMINANT_POLLUTANT_CONCENTRATION",
                        "LOCAL_AQI"
                    ],
                    "languageCode": "en",
                    "universalAqi": false
                }
            """.trimIndent()
            
            Log.d(TAG, "Sending API request...")
            connection.outputStream.use { os ->
                os.write(requestBody.toByteArray())
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "API Response Code: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                Log.d(TAG, "✓✓✓ API Response received (${response.length} bytes)")
                return parseAirQualityResponse(response)
            } else {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() } ?: "No error details"
                Log.e(TAG, "✗✗✗ API Error: $responseCode - $errorBody")
                return AirQualityResult(0, "API Error", "N/A")
            }
        } catch (e: Exception) {
            Log.e(TAG, "✗✗✗ Exception during API call: ${e.message}")
            e.printStackTrace()
            return AirQualityResult(0, "Network Error", "N/A")
        } finally {
            connection.disconnect()
        }
    }

    private fun parseAirQualityResponse(jsonString: String): AirQualityResult {
        try {
            val json = JSONObject(jsonString)
            val indexes = json.optJSONArray("indexes")
            
            if (indexes != null && indexes.length() > 0) {
                var aqiIndex: JSONObject? = null
                for (i in 0 until indexes.length()) {
                    val index = indexes.getJSONObject(i)
                    val code = index.optString("code")
                    if (code == "ind_cpcb") {
                        aqiIndex = index
                        break
                    }
                }
                
                if (aqiIndex == null) {
                    aqiIndex = indexes.getJSONObject(0)
                }
                
                val aqi = aqiIndex.optInt("aqi", 0)
                val category = aqiIndex.optString("category", "Unknown")
                val dominantPollutantCode = aqiIndex.optString("dominantPollutant", "N/A")
                val dominantPollutant = formatPollutantName(dominantPollutantCode)
                
                Log.d(TAG, "✓ Parsed: AQI=$aqi, Category=$category, Pollutant=$dominantPollutant")
                return AirQualityResult(aqi, category, dominantPollutant)
            }
            
            return AirQualityResult(0, "No Data", "N/A")
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing response: ${e.message}")
            return AirQualityResult(0, "Parse Error", "N/A")
        }
    }

    private fun formatPollutantName(code: String): String {
        return when (code.lowercase()) {
            "pm25" -> "PM2.5"
            "pm10" -> "PM10"
            "o3" -> "Ozone"
            "no2" -> "NO₂"
            "so2" -> "SO₂"
            "co" -> "CO"
            else -> code.uppercase()
        }
    }

    private fun getCurrentTime(): String {
        val sdf = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        return sdf.format(Date())
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

        paint.color = Color.parseColor("#E0E0E0")
        paint.strokeCap = Paint.Cap.ROUND
        canvas.drawArc(rectF, 135f, 270f, false, paint)

        if (aqi > 0) {
            val normalizedAqi = min(aqi.toFloat(), 500f)
            val progress = normalizedAqi / 500f
            val totalSweepAngle = 270f
            val sweepAngle = progress * totalSweepAngle

            val segments = 100
            val segmentAngle = sweepAngle / segments

            for (i in 0..segments) {
                val segmentProgress = i.toFloat() / segments
                val aqiAtProgress = segmentProgress * normalizedAqi

                paint.color = getColorForAqi(aqiAtProgress)
                
                paint.strokeCap = when {
                    i == 0 -> Paint.Cap.ROUND
                    i == segments -> Paint.Cap.ROUND
                    else -> Paint.Cap.BUTT
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
                lerpColor(
                    Color.parseColor("#00E400"),
                    Color.parseColor("#A8D96E"),
                    aqiValue / 100f
                )
            }
            aqiValue <= 150 -> {
                lerpColor(
                    Color.parseColor("#A8D96E"),
                    Color.parseColor("#FFFF00"),
                    (aqiValue - 100f) / 50f
                )
            }
            aqiValue <= 200 -> {
                lerpColor(
                    Color.parseColor("#FFFF00"),
                    Color.parseColor("#FF7E00"),
                    (aqiValue - 150f) / 50f
                )
            }
            aqiValue <= 300 -> {
                lerpColor(
                    Color.parseColor("#FF7E00"),
                    Color.parseColor("#FF0000"),
                    (aqiValue - 200f) / 100f
                )
            }
            aqiValue <= 400 -> {
                lerpColor(
                    Color.parseColor("#FF0000"),
                    Color.parseColor("#990000"),
                    (aqiValue - 300f) / 100f
                )
            }
            else -> {
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

    data class AirQualityResult(
        val aqi: Int,
        val category: String,
        val dominantPollutant: String
    )
}