package com.transactionapp.transaction_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.content.Context

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/notif_channel")
            .setMethodCallHandler { call, result ->
                if (call.method == "createNotificationChannel") {
                    val channelId = call.argument<String>("id") ?: "mpesa_sniffer_channel"
                    val name = call.argument<String>("name") ?: "M-Pesa Sniffer"
                    val descriptionText = call.argument<String>("description") ?: "Transaction sniffer service"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val importance = NotificationManager.IMPORTANCE_HIGH
                        val channel = NotificationChannel(channelId, name, importance)
                        channel.description = descriptionText
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.createNotificationChannel(channel)
                    }
                    result.success(true)
                } else if (call.method == "scanFile") {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        android.media.MediaScannerConnection.scanFile(applicationContext, arrayOf(path), null) { _, _ -> }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
