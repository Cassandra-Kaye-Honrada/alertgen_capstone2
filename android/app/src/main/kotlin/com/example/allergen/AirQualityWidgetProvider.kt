package com.example.allergen

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.util.Log
import android.location.Location
import android.location.LocationManager
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import kotlinx.coroutines.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import android.location.Geocoder
import java.util.Locale
import java.text.SimpleDateFormat
import java.util.Date

class AirQualityWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "AirQualityWidget"
        private const val API_KEY = "AIzaSyCWva81wgqeq5qIShLvoO9hs20ejk73gCE"
        
        private const val DEFAULT_LATITUDE = 16.0447
        private const val DEFAULT_LONGITUDE = 120.4794
        
        private const val ACTION_REFRESH = "com.example.allergen.ACTION_REFRESH_AIR_QUALITY"
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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == ACTION_REFRESH) {
            Log.d(TAG, "🔄 Refresh button clicked")
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, AirQualityWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            Log.d(TAG, "🌤️ Updating widget ID: $appWidgetId")
            
            val views = RemoteViews(context.packageName, R.layout.air_quality_widget_layout)
            
            // Set up main click intent (opens app)
            val mainIntent = Intent(context, MainActivity::class.java).apply {
                action = "AIR_QUALITY_ACTION"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val mainPendingIntent = PendingIntent.getActivity(
                context,
                2,
                mainIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.air_quality_widget_container, mainPendingIntent)
            
            // Set up refresh button click intent
            val refreshIntent = Intent(context, AirQualityWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                3,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)
            
            // Show loading state
            views.setTextViewText(R.id.timestamp, "Updating...")
            appWidgetManager.updateAppWidget(appWidgetId, views)
            
            // Fetch air quality data asynchronously
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val location = getLocation(context)
                    val (latitude, longitude, locationName) = if (location != null) {
                        Log.d(TAG, "✅ Using actual location")
                        Triple(
                            location.latitude,
                            location.longitude,
                            getLocationName(context, location.latitude, location.longitude)
                        )
                    } else {
                        Log.d(TAG, "⚠️ Using default location (permissions not granted)")
                        Triple(
                            DEFAULT_LATITUDE,
                            DEFAULT_LONGITUDE,
                            "Tap to enable location"
                        )
                    }
                    
                    val airQualityData = fetchAirQuality(latitude, longitude)
                    
                    withContext(Dispatchers.Main) {
                        updateWidgetWithData(
                            context,
                            appWidgetManager,
                            appWidgetId,
                            airQualityData,
                            locationName,
                            location == null
                        )
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error fetching air quality: ${e.message}")
                    withContext(Dispatchers.Main) {
                        updateWidgetWithError(context, appWidgetManager, appWidgetId)
                    }
                }
            }
            
            Log.d(TAG, "✅ Air Quality widget update initiated")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating air quality widget: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun getLocation(context: Context): Location? {
        try {
            if (ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.e(TAG, "❌ Location permissions not granted")
                return null
            }

            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            
            var location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            
            if (location == null) {
                location = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            }
            
            if (location == null) {
                location = locationManager.getLastKnownLocation(LocationManager.PASSIVE_PROVIDER)
            }
            
            if (location != null) {
                Log.d(TAG, "📍 Location: ${location.latitude}, ${location.longitude}")
            } else {
                Log.e(TAG, "❌ No location available from any provider")
            }
            
            return location
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting location: ${e.message}")
            return null
        }
    }

    private fun getLocationName(context: Context, latitude: Double, longitude: Double): String {
        return try {
            val geocoder = Geocoder(context, Locale.getDefault())
            val addresses = geocoder.getFromLocation(latitude, longitude, 1)
            if (addresses != null && addresses.isNotEmpty()) {
                val address = addresses[0]
                address.locality ?: address.subAdminArea ?: "Current Location"
            } else {
                "Current Location"
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting location name: ${e.message}")
            "Current Location"
        }
    }

    private fun fetchAirQuality(latitude: Double, longitude: Double): AirQualityResult {
        val url = URL("https://airquality.googleapis.com/v1/currentConditions:lookup?key=$API_KEY")
        val connection = url.openConnection() as HttpURLConnection
        
        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
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
            
            connection.outputStream.use { os ->
                os.write(requestBody.toByteArray())
            }
            
            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                Log.d(TAG, "✅ API Response: $response")
                return parseAirQualityResponse(response)
            } else {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() } ?: "No error details"
                Log.e(TAG, "❌ API Error: $responseCode - $errorBody")
                return AirQualityResult(0, "API Error", "N/A")
            }
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
                
                Log.d(TAG, "✅ Parsed AQI: $aqi, Category: $category, Pollutant: $dominantPollutant")
                return AirQualityResult(aqi, category, dominantPollutant)
            }
            
            return AirQualityResult(0, "No Data", "N/A")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error parsing response: ${e.message}")
            e.printStackTrace()
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

    private fun getCurrentTimestamp(): String {
        val sdf = SimpleDateFormat("MMM dd, h:mm a", Locale.getDefault())
        return "Updated: ${sdf.format(Date())}"
    }

    private fun updateWidgetWithData(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        data: AirQualityResult,
        locationName: String,
        showPermissionHint: Boolean = false
    ) {
        val views = RemoteViews(context.packageName, R.layout.air_quality_widget_layout)
        
        // Set up main click intent
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            action = "AIR_QUALITY_ACTION"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context,
            2,
            mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.air_quality_widget_container, mainPendingIntent)
        
        // Set up refresh button
        val refreshIntent = Intent(context, AirQualityWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            3,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)
        
        // Update with actual data
        views.setTextViewText(R.id.aqi_value, data.aqi.toString())
        views.setTextViewText(R.id.quality_level, data.category)
        views.setTextViewText(R.id.dominant_pollutant, "Dominant Pollutant: ${data.dominantPollutant}")
        
        val locationText = if (showPermissionHint) {
            "$locationName"
        } else {
            locationName
        }
        views.setTextViewText(R.id.location, locationText)
        
        // Update timestamp
        views.setTextViewText(R.id.timestamp, getCurrentTimestamp())
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "✅ Widget updated with data: AQI ${data.aqi}, Category: ${data.category}, Pollutant: ${data.dominantPollutant}, Location: $locationName")
    }

    private fun updateWidgetWithError(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.air_quality_widget_layout)
        
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            action = "AIR_QUALITY_ACTION"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context,
            2,
            mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.air_quality_widget_container, mainPendingIntent)
        
        // Set up refresh button
        val refreshIntent = Intent(context, AirQualityWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            3,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)
        
        views.setTextViewText(R.id.aqi_value, "!")
        views.setTextViewText(R.id.quality_level, "Error loading")
        views.setTextViewText(R.id.dominant_pollutant, "Tap to retry")
        views.setTextViewText(R.id.location, "Check connection")
        views.setTextViewText(R.id.timestamp, "Failed at ${SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date())}")
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
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

    data class AirQualityResult(
        val aqi: Int,
        val category: String,
        val dominantPollutant: String
    )
}