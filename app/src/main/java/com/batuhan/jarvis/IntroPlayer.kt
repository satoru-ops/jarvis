package com.batuhan.jarvis

import android.content.Context
import android.media.MediaPlayer

object IntroPlayer {
    private var mp: MediaPlayer? = null

    fun play(context: Context, onEnd: () -> Unit) {
        try {
            mp?.release()
            val p = MediaPlayer.create(context, R.raw.jarvis_voice)
            if (p == null) { onEnd(); return }
            mp = p
            p.setOnCompletionListener { it.release(); mp = null; onEnd() }
            p.start()
        } catch (e: Exception) {
            onEnd()
        }
    }

    fun release() {
        try { mp?.release() } catch (e: Exception) {}
        mp = null
    }
}
