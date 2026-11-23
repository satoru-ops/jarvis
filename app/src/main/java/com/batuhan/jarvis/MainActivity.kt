package com.batuhan.jarvis

import android.Manifest
import android.app.ActivityManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.BatteryManager
import android.os.Bundle
import android.os.CountDownTimer
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.text.InputType
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.sin

class MainActivity : AppCompatActivity(), TextToSpeech.OnInitListener {

    private lateinit var orb: OrbView
    private lateinit var status: TextView
    private lateinit var titleView: TextView
    private lateinit var stateView: TextView
    private lateinit var micChip: TextView
    private lateinit var timeView: TextView
    private lateinit var dateView: TextView
    private lateinit var sysTitle: TextView
    private lateinit var sysInfo: TextView
    private lateinit var timerText: TextView
    private lateinit var warn: TextView
    private lateinit var input: EditText
    private lateinit var btnSwitch: Button
    private lateinit var btnMic: Button
    private lateinit var btnSettings: Button
    private lateinit var btnSend: Button
    private lateinit var rootView: View
    private lateinit var cardTime: View
    private lateinit var cardSys: View

    private lateinit var prefs: Prefs
    private lateinit var gemini: GeminiClient
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var recognizer: SpeechRecognizer? = null
    private var cd: CountDownTimer? = null

    private var ultron = false
    private var speaking = false
    private var listening = false
    private var foreground = false
    private val ui = Handler(Looper.getMainLooper())

    private val speakAnim = object : Runnable {
        override fun run() {
            if (speaking) {
                val t = System.currentTimeMillis() / 90.0
                orb.setLevel((0.45 + 0.35 * sin(t) + 0.2 * sin(t * 2.3)).toFloat())
                ui.postDelayed(this, 60)
            }
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            val loc = Locale("tr", "TR")
            val now = Date()
            timeView.text = SimpleDateFormat("HH:mm", loc).format(now)
            dateView.text = SimpleDateFormat("EEEE · d MMMM", loc).format(now).uppercase(loc)
            val bm = getSystemService(BATTERY_SERVICE) as BatteryManager
            val bat = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val mi = ActivityManager.MemoryInfo()
            (getSystemService(ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(mi)
            val ram = 100 - (mi.availMem * 100 / mi.totalMem).toInt()
            val sf = StatFs(Environment.getDataDirectory().path)
            val disk = 100 - (sf.availableBytes * 100 / sf.totalBytes).toInt()
            sysInfo.text = "PİL   %" + bat + "\nRAM   %" + ram + "\nDİSK  %" + disk + " dolu"
            ui.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        orb = findViewById(R.id.orb)
        status = findViewById(R.id.status)
        titleView = findViewById(R.id.title)
        stateView = findViewById(R.id.state)
        micChip = findViewById(R.id.micChip)
        timeView = findViewById(R.id.timeView)
        dateView = findViewById(R.id.dateView)
        sysTitle = findViewById(R.id.sysTitle)
        sysInfo = findViewById(R.id.sysInfo)
        timerText = findViewById(R.id.timerText)
        warn = findViewById(R.id.warn)
        input = findViewById(R.id.input)
        btnSwitch = findViewById(R.id.btnSwitch)
        btnMic = findViewById(R.id.btnMic)
        btnSettings = findViewById(R.id.btnSettings)
        btnSend = findViewById(R.id.btnSend)
        rootView = findViewById(R.id.root)
        cardTime = findViewById(R.id.cardTime)
        cardSys = findViewById(R.id.cardSys)

        prefs = Prefs(this)
        gemini = GeminiClient(prefs)
        gemini.loadHistory()
        ultron = prefs.ultron()

        tts = TextToSpeech(this, this)
        applyMode()
        ui.post(tick)

        btnSwitch.setOnClickListener {
            ultron = !ultron
            prefs.saveUltron(ultron)
            applyMode()
            say(if (ultron) "Ultron devrede." else "Jarvis geri dondu efendim.")
        }
        btnMic.setOnClickListener { startListening() }
        btnSettings.setOnClickListener { showSettings() }
        btnSend.setOnClickListener { sendTyped() }
        input.setOnEditorActionListener { _, _, _ -> sendTyped(); true }

        findViewById<Button>(R.id.t1).setOnClickListener { startTimer(1) }
        findViewById<Button>(R.id.t5).setOnClickListener { startTimer(5) }
        findViewById<Button>(R.id.t10).setOnClickListener { startTimer(10) }
        findViewById<Button>(R.id.t25).setOnClickListener { startTimer(25) }
        timerText.setOnClickListener { cd?.cancel(); timerText.text = "--:--" }

        ensurePermission()
    }

    override fun onInit(s: Int) {
        if (s == TextToSpeech.SUCCESS) {
            tts?.language = Locale("tr", "TR")
            ttsReady = true
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {
                    ui.post { speaking = true; stateView.text = "KONUŞUYOR"; ui.post(speakAnim) }
                }
                override fun onDone(id: String?) {
                    ui.post { speaking = false; orb.setLevel(0f); stateView.text = "SESSİZ" }
                }
                @Deprecated("x")
                override fun onError(id: String?) {
                    ui.post { speaking = false; orb.setLevel(0f); stateView.text = "SESSİZ" }
                }
            })
            applyVoice()
        }
    }

    private fun applyVoice() {
        if (!ttsReady) return
        if (ultron) { tts?.setPitch(0.85f); tts?.setSpeechRate(0.95f) }
        else { tts?.setPitch(1.0f); tts?.setSpeechRate(1.0f) }
    }

    private fun applyMode() {
        val acc = Color.parseColor(if (ultron) "#FF2A2A" else "#2AB7FF")
        rootView.setBackgroundColor(Color.parseColor(if (ultron) "#0F0505" else "#05080F"))
        orb.ultron = ultron
        titleView.text = if (ultron) "U L T R O N" else "J A R V I S"
        for (t in listOf(titleView, timeView, sysTitle, micChip, timerText)) t.setTextColor(acc)
        for (b in listOf(findViewById<Button>(R.id.t1), findViewById<Button>(R.id.t5),
            findViewById<Button>(R.id.t10), findViewById<Button>(R.id.t25))) b.setTextColor(acc)
        for (c in listOf(cardTime, cardSys, warn)) {
            val g = GradientDrawable()
            g.setColor(0x14FFFFFF)
            g.setStroke(2, (acc and 0x00FFFFFF) or 0x66000000)
            g.cornerRadius = 14f
            c.background = g
        }
        warn.setTextColor(acc)
        warn.visibility = if (ultron) View.VISIBLE else View.GONE
        btnSwitch.text = if (ultron) "JARVIS" else "ULTRON"
        applyVoice()
    }

    private fun say(text: String) {
        status.text = text
        if (!foreground) Notifier.send(this, text)
        if (!ttsReady) return
        applyVoice()
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "u" + System.currentTimeMillis())
    }

    private fun startTimer(min: Int) {
        cd?.cancel()
        cd = object : CountDownTimer(min * 60000L, 1000) {
            override fun onTick(ms: Long) {
                val s = ms / 1000
                timerText.text = String.format("%02d:%02d", s / 60, s % 60)
            }
            override fun onFinish() {
                timerText.text = "--:--"
                say("Zamanlayici bitti efendim.")
            }
        }.start()
        say(min.toString() + " dakikalik zamanlayici kuruldu.")
    }

    private fun ensurePermission() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO, "android.permission.POST_NOTIFICATIONS"), 1)
        }
    }

    private fun startListening() {
        if (listening || speaking) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ensurePermission()
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            status.text = "Bu telefonda ses tanima yok."
            return
        }
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {
                listening = true
                stateView.text = "DİNLİYOR"
                micChip.text = "● MİKROFON AÇIK"
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rms: Float) {
                orb.setLevel(((rms + 2f) / 12f).coerceIn(0f, 1f))
            }
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() { micOff() }
            override fun onError(e: Int) { micOff(); stateView.text = "SESSİZ" }
            override fun onResults(r: Bundle?) {
                micOff()
                val said = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.trim() ?: ""
                if (said.isNotEmpty()) process(said) else stateView.text = "SESSİZ"
            }
            override fun onPartialResults(p: Bundle?) {}
            override fun onEvent(t: Int, p: Bundle?) {}
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "tr-TR")
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
        recognizer?.startListening(i)
    }

    private fun micOff() {
        listening = false
        orb.setLevel(0f)
        micChip.text = "● MİKROFON KAPALI"
    }

    private fun sendTyped() {
        val t = input.text.toString().trim()
        if (t.isEmpty()) return
        input.setText("")
        process(t)
    }

    private fun process(text: String) {
        stateView.text = "DÜŞÜNÜYOR"
        status.text = "..."
        Thread {
            val cmd = try { Commands.handle(this, text) } catch (e: Exception) { null }
            val reply = cmd ?: gemini.ask(text, ultron)
            ui.post { say(reply) }
        }.start()
    }

    private fun showSettings() {
        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.setPadding(48, 24, 48, 0)

        val keyIn = EditText(this)
        keyIn.hint = "Gemini API anahtari"
        keyIn.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        keyIn.setText(prefs.apiKey())
        box.addView(keyIn)

        val modelIn = EditText(this)
        modelIn.hint = "Model adi"
        modelIn.setText(prefs.model())
        box.addView(modelIn)

        val clear = Button(this)
        clear.text = "Konusma gecmisini sil"
        clear.setOnClickListener {
            gemini.clearHistory()
            status.text = "Gecmis silindi."
        }
        box.addView(clear)

        AlertDialog.Builder(this)
            .setTitle("Ayarlar")
            .setView(box)
            .setPositiveButton("Kaydet") { _, _ ->
                prefs.saveApiKey(keyIn.text.toString())
                prefs.saveModel(modelIn.text.toString())
            }
            .setNegativeButton("Iptal", null)
            .show()
    }

    override fun onResume() { super.onResume(); foreground = true }
    override fun onPause() { super.onPause(); foreground = false }

    override fun onDestroy() {
        ui.removeCallbacks(tick)
        cd?.cancel()
        recognizer?.destroy()
        tts?.shutdown()
        super.onDestroy()
    }
}
