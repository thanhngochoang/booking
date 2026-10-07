package com.thanhbk.photobooking

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * `default` makes sound; `quiet` is for pushes inside the user's quiet hours
     * (no sound, no vibration). The server picks one per push (plan 10a, S17.02).
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel("default", "Thông báo", NotificationManager.IMPORTANCE_HIGH),
        )
        val quiet = NotificationChannel(
            "quiet",
            "Thông báo yên lặng",
            NotificationManager.IMPORTANCE_LOW,
        )
        quiet.setSound(null, null)
        quiet.enableVibration(false)
        manager.createNotificationChannel(quiet)
    }
}
