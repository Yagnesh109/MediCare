package com.example.medicare_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            // Start the app or service to reschedule notifications
            val flutterEngine = FlutterEngine(context!!)
            flutterEngine.dartExecutor.executeDartEntrypoint(
                io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint.createDefault()
            )
            
            // Call method to reschedule notifications
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "medicare_app/notifications")
                .invokeMethod("rescheduleNotifications", null)
        }
    }
}
