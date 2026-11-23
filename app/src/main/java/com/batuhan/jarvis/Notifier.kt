package com.batuhan.jarvis

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat

object Notifier {
    private const val CH = "jarvis"

    fun send(context: Context, text: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(CH, "Jarvis", NotificationManager.IMPORTANCE_HIGH)
            )
            val n = NotificationCompat.Builder(context, CH)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Jarvis")
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setAutoCancel(true)
                .build()
            nm.notify((System.currentTimeMillis() % 100000).toInt(), n)
        } catch (e: Exception) {
        }
    }
}
