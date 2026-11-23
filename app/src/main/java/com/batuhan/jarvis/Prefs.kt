package com.batuhan.jarvis

import android.content.Context

class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("jarvis", Context.MODE_PRIVATE)

    fun apiKey(): String = sp.getString("key", "") ?: ""
    fun saveApiKey(v: String) = sp.edit().putString("key", v.trim()).apply()

    fun model(): String = sp.getString("model", "gemini-3.5-flash") ?: "gemini-3.5-flash"
    fun saveModel(v: String) = sp.edit().putString("model", v.trim()).apply()

    fun loadHistory(): String = sp.getString("history", "") ?: ""
    fun saveHistory(v: String) = sp.edit().putString("history", v).apply()

    fun ultron(): Boolean = sp.getBoolean("ultron", false)
    fun saveUltron(v: Boolean) = sp.edit().putBoolean("ultron", v).apply()

    fun hotword(): Boolean = sp.getBoolean("hotword", false)
    fun saveHotword(v: Boolean) = sp.edit().putBoolean("hotword", v).apply()
}
