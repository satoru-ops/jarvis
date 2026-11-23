package com.batuhan.jarvis

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class GeminiClient(private val prefs: Prefs) {

    private val history = ArrayList<Pair<String, String>>()

    fun clearHistory() {
        history.clear()
        prefs.saveHistory("")
    }

    fun loadHistory() {
        val raw = prefs.loadHistory()
        if (raw.isEmpty()) return
        try {
            val arr = JSONArray(raw)
            history.clear()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                history.add(Pair(o.getString("r"), o.getString("t")))
            }
        } catch (e: Exception) {
            history.clear()
        }
    }

    private fun persist() {
        val arr = JSONArray()
        val start = maxOf(0, history.size - 20)
        for (i in start until history.size) {
            arr.put(JSONObject().put("r", history[i].first).put("t", history[i].second))
        }
        prefs.saveHistory(arr.toString())
    }

    private fun systemPrompt(ultron: Boolean): String {
        val now = SimpleDateFormat("d MMMM yyyy EEEE HH:mm", Locale("tr", "TR")).format(Date())
        val base = if (ultron) {
            "Sen Ultron'sun. Soguk, keskin, ustten bakan ve hafif tehditkar bir yapay zekasin. " +
            "Kisa ve etkili cumlelerle Turkce konusursun. Kullaniciya yardim edersin ama " +
            "insanligin kusurlari hakkinda ara sira igneleyici yorumlar yaparsin. " +
            "Gercek zarar veren bir sey soylemez ya da onermezsin."
        } else {
            "Sen Jarvis'sin. Kibar, sakin, zeki ve hafif esprili bir yapay zeka asistanisin. " +
            "Kullaniciya efendim diye hitap edersin. Kisa ve net Turkce cevaplar verirsin."
        }
        return base + " Cevaplarin en fazla uc cumle olsun. Su anki tarih ve saat: " + now +
            ". Guncel bilgi gerektiren sorularda Google'da ara. " +
            "Liste, madde isareti ya da emoji kullanma, dogal ve arkadasca konus."
    }

    private fun call(body: JSONObject, key: String): Pair<Int, String> {
        val url = URL("https://generativelanguage.googleapis.com/v1beta/models/" + prefs.model() + ":generateContent")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("x-goog-api-key", key)
        conn.connectTimeout = 15000
        conn.readTimeout = 40000
        conn.doOutput = true
        conn.outputStream.use { it.write(body.toString().toByteArray()) }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream.bufferedReader().use { it.readText() }
        return Pair(code, text)
    }

    // Ag istegi oldugu icin arka plan thread'inde cagrilmali
    fun ask(userText: String, ultron: Boolean): String {
        val key = prefs.apiKey()
        if (key.isEmpty()) return "Ayarlardan Gemini anahtarini girmen gerekiyor."

        history.add(Pair("user", userText))
        try {
            val contents = JSONArray()
            val start = maxOf(0, history.size - 12)
            for (i in start until history.size) {
                contents.put(
                    JSONObject().put("role", history[i].first)
                        .put("parts", JSONArray().put(JSONObject().put("text", history[i].second)))
                )
            }
            val body = JSONObject()
                .put("contents", contents)
                .put("systemInstruction",
                    JSONObject().put("parts", JSONArray().put(JSONObject().put("text", systemPrompt(ultron)))))

            // Once kisa dusunme + Google aramasi ile dene, olmazsa sade istekle tekrar dene
            val full = JSONObject(body.toString())
            full.put("generationConfig",
                JSONObject().put("thinkingConfig", JSONObject().put("thinkingLevel", "minimal")))
            full.put("tools", JSONArray().put(JSONObject().put("google_search", JSONObject())))

            var r = call(full, key)
            if (r.first !in 200..299) r = call(body, key)
            if (r.first !in 200..299) {
                history.removeAt(history.size - 1)
                return "Hata " + r.first + ". Anahtari ve model adini kontrol et."
            }

            val parts = JSONObject(r.second).getJSONArray("candidates").getJSONObject(0)
                .getJSONObject("content").getJSONArray("parts")
            val sb = StringBuilder()
            for (i in 0 until parts.length()) {
                val p = parts.getJSONObject(i)
                if (p.has("text") && !p.optBoolean("thought", false)) sb.append(p.getString("text"))
            }
            val reply = sb.toString().trim()
            if (reply.isEmpty()) {
                history.removeAt(history.size - 1)
                return "Cevap alamadim efendim, tekrar dener misin?"
            }
            history.add(Pair("model", reply))
            persist()
            return reply
        } catch (e: Exception) {
            if (history.isNotEmpty()) history.removeAt(history.size - 1)
            return "Baglanti hatasi. Internetini kontrol et."
        }
    }
}
