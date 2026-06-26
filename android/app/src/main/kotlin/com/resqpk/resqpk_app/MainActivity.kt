package com.resqpk.resqpk_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val general = NotificationChannel(
                "resqpk_general", "General", NotificationManager.IMPORTANCE_DEFAULT
            )
            val emergency = NotificationChannel(
                "emergency_dispatch", "Emergency Dispatch", NotificationManager.IMPORTANCE_HIGH
            )
            val tips = NotificationChannel(
                "weekly_tips", "Weekly Tips", NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannels(listOf(general, emergency, tips))
        }
    }
}
