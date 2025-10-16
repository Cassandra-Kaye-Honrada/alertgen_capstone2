// android/app/src/main/kotlin/com/example/allergen/MainActivity.kt
package com.example.allergen

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telecom.TelecomManager
import android.telephony.PhoneStateListener
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val SMS_CHANNEL = "emergency_sms"
    private val CALL_CHANNEL = "emergency_call_manager"
    private val SMS_PERMISSION_REQUEST = 101
    private val CALL_PERMISSION_REQUEST = 102
    private val TAG = "EmergencyApp"

    // Call management properties
    private var callStateListener: PhoneStateListener? = null
    private var telephonyManager: TelephonyManager? = null
    private var telecomManager: TelecomManager? = null
    private var isCallActive = false
    private var currentPhoneNumber: String? = null
    private var callStartTime: Long = 0
    private var callMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "🔧 Configuring Flutter engine...")
        
        // SMS Channel
     MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
    Log.d(TAG, "📱 SMS Channel - Method: ${call.method}")
    when (call.method) {
        "sendSMS", "sendDirectSMS" -> {
            val phoneNumber = call.argument<String>("phoneNumber")
            val message = call.argument<String>("message")

            if (phoneNumber != null && message != null) {
                sendSMS(phoneNumber, message, result)
            } else {
                result.error("INVALID_ARGUMENTS", "Phone number and message are required", null)
            }
        }
        else -> {
            result.notImplemented()
        }
    }
}


        // Call Management Channel
        callMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
        callMethodChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "📞 Call Channel - Method: ${call.method}")
            when (call.method) {
                "startCallStateMonitoring" -> {
                    Log.d(TAG, "🔧 Starting call state monitoring...")
                    if (checkCallPermissions()) {
                        Log.d(TAG, "✅ Permissions granted, starting monitoring")
                        startCallStateMonitoring()
                        result.success(true)
                    } else {
                        Log.d(TAG, "❌ Permissions not granted, requesting...")
                        requestCallPermissions()
                        result.error("PERMISSION_DENIED", "Required permissions not granted", null)
                    }
                }
                "endCurrentCall" -> {
                    Log.d(TAG, "🔧 Attempting to end current call...")
                    val success = endCurrentCall()
                    Log.d(TAG, "🔧 End call result: $success")
                    result.success(success)
                }
                "isInCall" -> {
                    Log.d(TAG, "🔧 Checking if in call...")
                    val inCall = isInCall()
                    Log.d(TAG, "🔧 In call result: $inCall")
                    result.success(inCall)
                }
                else -> {
                    Log.d(TAG, "❓ Unknown call method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
        
        // Initialize telephony managers
        try {
            telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            Log.d(TAG, "✅ TelephonyManager initialized")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                Log.d(TAG, "✅ TelecomManager initialized")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing managers: ${e.message}")
        }
    }

    // SMS Functionality
    private fun sendSMS(phoneNumber: String, message: String, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "📱 Attempting to send SMS to: $phoneNumber")
            
            // Check if SMS permission is granted
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) 
                != PackageManager.PERMISSION_GRANTED) {
                Log.e(TAG, "❌ SMS permission not granted")
                result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                return
            }

            val smsManager = SmsManager.getDefault()
            
            // For long messages, divide into multiple parts
            val parts = smsManager.divideMessage(message)
            
            if (parts.size == 1) {
                // Single SMS
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                Log.d(TAG, "✅ Single SMS sent")
            } else {
                // Multiple SMS parts
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                Log.d(TAG, "✅ Multipart SMS sent (${parts.size} parts)")
            }
            
            result.success(true)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ SMS failed: ${e.message}")
            result.error("SMS_FAILED", "Failed to send SMS: ${e.message}", null)
        }
    }

    // Call Management Functionality
    private fun checkCallPermissions(): Boolean {
        val permissions = mutableListOf<String>()
        
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) 
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_PHONE_STATE)
            Log.d(TAG, "❌ READ_PHONE_STATE permission missing")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS) 
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.ANSWER_PHONE_CALLS)
                Log.d(TAG, "❌ ANSWER_PHONE_CALLS permission missing")
            }
        }
        
        val hasAllPermissions = permissions.isEmpty()
        Log.d(TAG, "🔧 All call permissions granted: $hasAllPermissions")
        return hasAllPermissions
    }

    private fun requestCallPermissions() {
        val permissions = mutableListOf<String>()
        
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) 
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_PHONE_STATE)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS) 
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.ANSWER_PHONE_CALLS)
            }
        }
        
        if (permissions.isNotEmpty()) {
            Log.d(TAG, "🔧 Requesting permissions: ${permissions.joinToString()}")
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), CALL_PERMISSION_REQUEST)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        Log.d(TAG, "🔧 Permission result - Request code: $requestCode")
        
        when (requestCode) {
            CALL_PERMISSION_REQUEST -> {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                Log.d(TAG, "🔧 Call permissions granted: $allGranted")
                if (allGranted) {
                    startCallStateMonitoring()
                }
            }
            SMS_PERMISSION_REQUEST -> {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                Log.d(TAG, "🔧 SMS permissions granted: $allGranted")
            }
        }
    }

    private fun startCallStateMonitoring() {
        try {
            Log.d(TAG, "🔧 Setting up call state listener...")
            
            callStateListener = object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    super.onCallStateChanged(state, phoneNumber)
                    
                    val stateString = when (state) {
                        TelephonyManager.CALL_STATE_IDLE -> "IDLE"
                        TelephonyManager.CALL_STATE_RINGING -> "RINGING"
                        TelephonyManager.CALL_STATE_OFFHOOK -> "OFFHOOK"
                        else -> "UNKNOWN($state)"
                    }
                    
                    Log.d(TAG, "📞 Call state changed: $stateString, number: $phoneNumber")
                    
                    when (state) {
                        TelephonyManager.CALL_STATE_IDLE -> {
                            // Call ended
                            if (isCallActive) {
                                val duration = if (callStartTime > 0) {
                                    (System.currentTimeMillis() - callStartTime) / 1000
                                } else 0
                                
                                Log.d(TAG, "📞 Call ended - Duration: ${duration}s")
                                notifyCallEnded(currentPhoneNumber, duration)
                                isCallActive = false
                                currentPhoneNumber = null
                                callStartTime = 0
                            }
                        }
                        TelephonyManager.CALL_STATE_RINGING -> {
                            // Incoming call ringing
                            Log.d(TAG, "📞 Incoming call ringing: $phoneNumber")
                            currentPhoneNumber = phoneNumber
                        }
                        TelephonyManager.CALL_STATE_OFFHOOK -> {
                            // Call active (outgoing or answered incoming)
                            if (!isCallActive) {
                                Log.d(TAG, "📞 Call became active")
                                isCallActive = true
                                currentPhoneNumber = phoneNumber ?: currentPhoneNumber
                                callStartTime = System.currentTimeMillis()
                                notifyCallStateChanged(true, currentPhoneNumber)
                            }
                        }
                    }
                }
            }
            
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) 
                == PackageManager.PERMISSION_GRANTED) {
                telephonyManager?.listen(callStateListener, PhoneStateListener.LISTEN_CALL_STATE)
                Log.d(TAG, "✅ Call state listener registered")
            } else {
                Log.e(TAG, "❌ Cannot register call state listener - no permission")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting up call state monitoring: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun endCurrentCall(): Boolean {
        return try {
            Log.d(TAG, "🔧 Attempting to end call - API Level: ${Build.VERSION.SDK_INT}")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Android 9+ (API 28+)
                Log.d(TAG, "🔧 Using TelecomManager.endCall() for API 28+")
                if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS) 
                    == PackageManager.PERMISSION_GRANTED) {
                    val result = telecomManager?.endCall() ?: false
                    Log.d(TAG, "🔧 TelecomManager.endCall() result: $result")
                    result
                } else {
                    Log.e(TAG, "❌ ANSWER_PHONE_CALLS permission not granted")
                    false
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                // Android 5.0 - 8.1 (API 21-27)
                Log.d(TAG, "🔧 Using reflection for API 21-27")
                try {
                    val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                    val c = Class.forName(tm.javaClass.name)
                    val m = c.getDeclaredMethod("getITelephony")
                    m.isAccessible = true
                    val telephonyService = m.invoke(tm)
                    val telephonyServiceClass = Class.forName(telephonyService.javaClass.name)
                    val endCallMethod = telephonyServiceClass.getDeclaredMethod("endCall")
                    endCallMethod.invoke(telephonyService)
                    Log.d(TAG, "✅ Reflection method succeeded")
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Reflection method failed: ${e.message}")
                    e.printStackTrace()
                    false
                }
            } else {
                // Pre-Android 5.0 - use reflection (less reliable)
                Log.d(TAG, "🔧 Using legacy reflection for pre-API 21")
                try {
                    val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                    val c = Class.forName(tm.javaClass.name)
                    val m = c.getDeclaredMethod("getITelephony")
                    m.isAccessible = true
                    val telephonyService = m.invoke(tm)
                    val telephonyServiceClass = Class.forName(telephonyService.javaClass.name)
                    val endCallMethod = telephonyServiceClass.getDeclaredMethod("endCall")
                    endCallMethod.invoke(telephonyService)
                    Log.d(TAG, "✅ Legacy reflection succeeded")
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Legacy reflection failed: ${e.message}")
                    e.printStackTrace()
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ End call failed: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun isInCall(): Boolean {
        return try {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) 
                == PackageManager.PERMISSION_GRANTED) {
                val state = telephonyManager?.callState
                val inCall = state == TelephonyManager.CALL_STATE_OFFHOOK
                Log.d(TAG, "🔧 Call state check - State: $state, InCall: $inCall")
                inCall
            } else {
                Log.e(TAG, "❌ Cannot check call state - no permission")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking call state: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun notifyCallStateChanged(isActive: Boolean, phoneNumber: String?) {
        Log.d(TAG, "🔔 Notifying call state changed: $isActive, $phoneNumber")
        val args = mapOf(
            "isCallActive" to isActive,
            "phoneNumber" to phoneNumber
        )
        try {
            callMethodChannel?.invokeMethod("onCallStateChanged", args)
            Log.d(TAG, "✅ Call state notification sent")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to send call state notification: ${e.message}")
        }
    }

    private fun notifyCallEnded(phoneNumber: String?, duration: Long) {
        Log.d(TAG, "🔔 Notifying call ended: $phoneNumber, duration: ${duration}s")
        val args = mapOf(
            "phoneNumber" to phoneNumber,
            "duration" to duration
        )
        try {
            callMethodChannel?.invokeMethod("onCallEnded", args)
            Log.d(TAG, "✅ Call ended notification sent")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to send call ended notification: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🔧 Destroying MainActivity...")
        callStateListener?.let {
            telephonyManager?.listen(it, PhoneStateListener.LISTEN_NONE)
            Log.d(TAG, "✅ Call state listener unregistered")
        }
        callMethodChannel?.setMethodCallHandler(null)
    }
}
