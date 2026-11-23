#!/bin/bash
set -e

# 1) Bildirim gonderen yeni dosya
cat > app/src/main/java/com/batuhan/jarvis/Notifier.kt << 'EOF'
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
EOF

# 2) Manifest'e bildirim izni
sed -i '/RECORD_AUDIO/a\    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />' app/src/main/AndroidManifest.xml

# 3) MainActivity degisiklikleri
F=app/src/main/java/com/batuhan/jarvis/MainActivity.kt

# izin istegine bildirimi de ekle
sed -i 's/requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1)/requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO, "android.permission.POST_NOTIFICATIONS"), 1)/' $F

# on plan takibi icin degisken
sed -i 's/^    private var listening = false$/    private var listening = false\n    private var foreground = false/' $F

# say() icinde uygulama arka plandaysa bildirim gonder
sed -i 's/^        status.text = text$/        status.text = text\n        if (!foreground) Notifier.send(this, text)/' $F

# onResume / onPause
sed -i '/override fun onDestroy() {/i\    override fun onResume() { super.onResume(); foreground = true }\n    override fun onPause() { super.onPause(); foreground = false }\n' $F

git add -A
git commit -m "Saat icin bildirim destegi"
git push