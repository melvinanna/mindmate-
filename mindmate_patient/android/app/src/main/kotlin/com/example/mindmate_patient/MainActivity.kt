package com.example.mindmate_patient

import android.os.Build
import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "sms_channel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSms") {
                val phone = call.argument<String>("phone")
                val msg = call.argument<String>("msg")

                if (phone != null && msg != null) {
                    try {
                        // Obtain SmsManager for the default subscription ID (more reliable on multi-SIM devices)
                        val subId = SmsManager.getDefaultSmsSubscriptionId()
                        val smsManager: SmsManager? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val manager = this@MainActivity.getSystemService(SmsManager::class.java)
                            manager?.createForSubscriptionId(subId)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getSmsManagerForSubscriptionId(subId)
                        }

                        if (smsManager != null) {
                            val parts = smsManager.divideMessage(msg)
                            smsManager.sendMultipartTextMessage(phone.trim(), null, parts, null, null)
                            result.success("Sent")
                        } else {
                            result.error("SMS_MANAGER_NULL", "Could not obtain SmsManager for SubID $subId", null)
                        }
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Phone or Message is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}