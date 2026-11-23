package com.batuhan.jarvis

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.AlarmClock
import java.net.URLEncoder

object Commands {

    fun handle(context: Context, raw: String): String? {
        val t = raw.lowercase().trim()

        if (t.contains("alarm")) {
            val m = Regex("(\\d{1,2})[ :.](\\d{2})").find(t)
            if (m != null) {
                val h = m.groupValues[1].toInt()
                val min = m.groupValues[2].toInt()
                if (h in 0..23 && min in 0..59) {
                    val i = Intent(AlarmClock.ACTION_SET_ALARM)
                        .putExtra(AlarmClock.EXTRA_HOUR, h)
                        .putExtra(AlarmClock.EXTRA_MINUTES, min)
                        .putExtra(AlarmClock.EXTRA_MESSAGE, "Jarvis")
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(i)
                    return "Alarm " + h + ":" + String.format("%02d", min) + " icin hazirlandi efendim."
                }
            }
        }

        if (t.contains("whatsapp") && (t.contains("yaz") || t.contains("gonder") || t.contains("gönder") || t.contains("mesaj"))) {
            var text = t
            for (w in listOf("whatsapp", "mesaj", "yaz", "gonder", "gönder", "ile", "bir")) {
                text = text.replace(w, " ")
            }
            text = text.trim().replace(Regex("\\s+"), " ")
            val uri = Uri.parse("https://wa.me/?text=" + URLEncoder.encode(text, "UTF-8"))
            val i = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(i)
            return "WhatsApp aciliyor efendim, kisiyi secip gonder tusuna basman yeterli."
        }

        if (t.startsWith("ara ") || t.contains("numarasini ara")) {
            val digits = t.filter { it.isDigit() }
            if (digits.length >= 7) {
                val i = Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + digits))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(i)
                return "Arama ekrani hazir efendim."
            }
        }

        if (t.endsWith(" ac") || t.endsWith(" aç") || t.contains(" uygulamasini ac")) {
            val name = t.replace("uygulamasini", "").removeSuffix(" ac").removeSuffix(" aç").trim()
            val pm = context.packageManager
            val apps = pm.getInstalledApplications(0)
            for (a in apps) {
                val label = pm.getApplicationLabel(a).toString().lowercase()
                if (label == name || label.contains(name)) {
                    val launch = pm.getLaunchIntentForPackage(a.packageName)
                    if (launch != null) {
                        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(launch)
                        return label + " aciliyor efendim."
                    }
                }
            }
            return "Boyle bir uygulama bulamadim efendim."
        }

        return null
    }
}
