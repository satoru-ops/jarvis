#!/bin/bash
# Jarvis uygulamasi - sifirdan temiz kurulum (Jarvis + Ultron, Gemini, Google arama, simge)
set -e

# Eski dosyalari temizle
rm -rf app
rm -f setup.sh update_ui.sh add_icon.sh fix_main.sh

mkdir -p .github/workflows
cat > .github/workflows/build.yml << 'EOF'
name: Build APK
on:
  workflow_dispatch:
  push:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: 8.7
      - run: gradle assembleDebug
      - uses: actions/upload-artifact@v4
        with:
          name: jarvis-apk
          path: app/build/outputs/apk/debug/app-debug.apk
EOF

mkdir -p .
cat > settings.gradle << 'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "Jarvis"
include ':app'
EOF

mkdir -p .
cat > build.gradle << 'EOF'
plugins {
    id 'com.android.application' version '8.5.2' apply false
    id 'org.jetbrains.kotlin.android' version '1.9.24' apply false
}
EOF

mkdir -p .
cat > gradle.properties << 'EOF'
android.useAndroidX=true
org.gradle.jvmargs=-Xmx2048m
EOF

mkdir -p .
cat > .gitignore << 'EOF'
.gradle/
build/
app/build/
local.properties
EOF

mkdir -p app
cat > app/build.gradle << 'EOF'
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace 'com.batuhan.jarvis'
    compileSdk 34

    defaultConfig {
        applicationId 'com.batuhan.jarvis'
        minSdk 26
        targetSdk 34
        versionCode 1
        versionName '1.0'
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.13.1'
    implementation 'androidx.appcompat:appcompat:1.7.0'
    implementation 'com.google.android.material:material:1.12.0'
}
EOF

mkdir -p app/src/main
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />

    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>

    <application
        android:allowBackup="true"
        android:label="Jarvis"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:theme="@style/Theme.AppCompat.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

mkdir -p app/src/main/java/com/batuhan/jarvis
cat > app/src/main/java/com/batuhan/jarvis/OrbView.kt << 'EOF'
package com.batuhan.jarvis

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import kotlin.math.sin

class OrbView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 4f
    }

    private var level = 0f
    private var smooth = 0f
    private var phase = 0f

    var ultron = false
        set(value) {
            field = value
            invalidate()
        }

    fun setLevel(v: Float) {
        level = v.coerceIn(0f, 1f)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val base = minOf(width, height) * 0.22f

        smooth += (level - smooth) * 0.18f
        phase += if (ultron) 0.05f else 0.09f

        val main = if (ultron) 0xFFFF2A2A.toInt() else 0xFF2AB7FF.toInt()
        val soft = if (ultron) 0x33FF2A2A else 0x332AB7FF

        val radius = base * (1f + smooth * 0.9f) + sin(phase) * base * 0.04f

        paint.shader = RadialGradient(
            cx, cy, radius * 2.2f,
            intArrayOf(soft, 0x00000000),
            floatArrayOf(0.3f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, radius * 2.2f, paint)

        paint.shader = RadialGradient(
            cx, cy, radius,
            intArrayOf(0xFFFFFFFF.toInt(), main, 0x00000000),
            floatArrayOf(0f, 0.55f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, radius, paint)
        paint.shader = null

        ringPaint.color = main
        for (i in 1..3) {
            val wobble = sin(phase * (1 + i * 0.4f) + i) * smooth * base * 0.25f
            ringPaint.alpha = (200 / i)
            canvas.drawCircle(cx, cy, radius * (1.15f + i * 0.28f) + wobble, ringPaint)
        }

        postInvalidateOnAnimation()
    }
}
EOF

mkdir -p app/src/main/java/com/batuhan/jarvis
cat > app/src/main/java/com/batuhan/jarvis/Prefs.kt << 'EOF'
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
EOF

mkdir -p app/src/main/java/com/batuhan/jarvis
cat > app/src/main/java/com/batuhan/jarvis/Commands.kt << 'EOF'
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
EOF

mkdir -p app/src/main/res/layout
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="#05080F">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="24dp"
        android:gravity="center_vertical"
        android:orientation="horizontal">

        <TextView
            android:id="@+id/title"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="J A R V I S"
            android:textSize="18sp"
            android:textStyle="bold"
            android:typeface="monospace" />

        <TextView
            android:id="@+id/state"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginStart="12dp"
            android:text="SESSİZ"
            android:textColor="#7F8FA3"
            android:textSize="11sp"
            android:typeface="monospace" />

        <View
            android:layout_width="0dp"
            android:layout_height="1dp"
            android:layout_weight="1" />

        <TextView
            android:id="@+id/micChip"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="● MİKROFON KAPALI"
            android:textSize="10sp"
            android:typeface="monospace" />
    </LinearLayout>

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="14dp"
        android:orientation="horizontal">

        <LinearLayout
            android:id="@+id/cardTime"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:orientation="vertical"
            android:padding="12dp">

            <TextView
                android:id="@+id/timeView"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="10:35"
                android:textSize="34sp"
                android:typeface="monospace" />

            <TextView
                android:id="@+id/dateView"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="#B0C4D8"
                android:textSize="10sp"
                android:typeface="monospace" />
        </LinearLayout>

        <LinearLayout
            android:id="@+id/cardSys"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_marginStart="10dp"
            android:layout_weight="1"
            android:orientation="vertical"
            android:padding="12dp">

            <TextView
                android:id="@+id/sysTitle"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="S İ S T E M"
                android:textSize="10sp"
                android:typeface="monospace" />

            <TextView
                android:id="@+id/sysInfo"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginTop="4dp"
                android:textColor="#B0C4D8"
                android:textSize="12sp"
                android:typeface="monospace" />
        </LinearLayout>
    </LinearLayout>

    <com.batuhan.jarvis.OrbView
        android:id="@+id/orb"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:gravity="center_vertical"
        android:orientation="horizontal">

        <TextView
            android:id="@+id/timerText"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:minWidth="64dp"
            android:text="--:--"
            android:textSize="16sp"
            android:typeface="monospace" />

        <Button android:id="@+id/t1" style="?android:attr/buttonBarButtonStyle"
            android:layout_width="0dp" android:layout_height="40dp" android:layout_weight="1"
            android:minWidth="0dp" android:padding="0dp" android:text="1 DK" android:textSize="11sp" />
        <Button android:id="@+id/t5" style="?android:attr/buttonBarButtonStyle"
            android:layout_width="0dp" android:layout_height="40dp" android:layout_weight="1"
            android:minWidth="0dp" android:padding="0dp" android:text="5 DK" android:textSize="11sp" />
        <Button android:id="@+id/t10" style="?android:attr/buttonBarButtonStyle"
            android:layout_width="0dp" android:layout_height="40dp" android:layout_weight="1"
            android:minWidth="0dp" android:padding="0dp" android:text="10 DK" android:textSize="11sp" />
        <Button android:id="@+id/t25" style="?android:attr/buttonBarButtonStyle"
            android:layout_width="0dp" android:layout_height="40dp" android:layout_weight="1"
            android:minWidth="0dp" android:padding="0dp" android:text="25 DK" android:textSize="11sp" />
    </LinearLayout>

    <TextView
        android:id="@+id/status"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:gravity="center"
        android:minLines="2"
        android:text="Sistemler çalışmaya hazır efendim."
        android:textColor="#E6EEF7"
        android:textSize="15sp" />

    <TextView
        android:id="@+id/warn"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:gravity="center"
        android:padding="10dp"
        android:text="⚠  ULTRON'U SERBEST BIRAKMA"
        android:textSize="12sp"
        android:textStyle="bold"
        android:typeface="monospace"
        android:visibility="gone" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:gravity="center_vertical"
        android:orientation="horizontal">

        <EditText
            android:id="@+id/input"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:hint="KONUŞ YA DA YAZ"
            android:imeOptions="actionSend"
            android:inputType="text"
            android:singleLine="true"
            android:textColor="#E6EEF7"
            android:textColorHint="#556070"
            android:textSize="14sp"
            android:typeface="monospace" />

        <Button
            android:id="@+id/btnSend"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="YAZ" />
    </LinearLayout>

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginBottom="16dp"
        android:gravity="center"
        android:orientation="horizontal">

        <Button
            android:id="@+id/btnSwitch"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="ULTRON" />

        <Button
            android:id="@+id/btnMic"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginStart="12dp"
            android:layout_marginEnd="12dp"
            android:text="KONUS" />

        <Button
            android:id="@+id/btnSettings"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="AYARLAR" />
    </LinearLayout>
</LinearLayout>
EOF

mkdir -p app/src/main/java/com/batuhan/jarvis
cat > app/src/main/java/com/batuhan/jarvis/MainActivity.kt << 'EOF'
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
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1)
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

    override fun onDestroy() {
        ui.removeCallbacks(tick)
        cd?.cancel()
        recognizer?.destroy()
        tts?.shutdown()
        super.onDestroy()
    }
}
EOF

mkdir -p app/src/main/java/com/batuhan/jarvis
cat > app/src/main/java/com/batuhan/jarvis/GeminiClient.kt << 'EOF'
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
EOF

mkdir -p app/src/main/res/values
cat > app/src/main/res/values/ic_colors.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_bg">#000000</color>
</resources>
EOF

mkdir -p app/src/main/res/mipmap-anydpi-v26
cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_bg" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
EOF

mkdir -p app/src/main/res/mipmap-mdpi
base64 -d > app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png << 'EOF'
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
der8vvm/VsTqMcvbCgsAAAAASUVORK5CYII=
EOF

mkdir -p app/src/main/res/mipmap-hdpi
base64 -d > app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png << 'EOF'
iVBORw0KGgoAAAANSUhEUgAAAKIAAACiCAIAAABNkIFMAAA5lElEQVR42u29d7xm11Xfvdbae59z
nv7cfu/cO71KM9KMercsWZYtdxuw4xIDMXEwgUBehxgImNAJ2AlgTEkDJwEbO8YGy9iWcVGzukZl
NL3f3p5ezjl777XeP547smyIZD6fNzN6h+f7ef6785n73PM7e++1VwXo06dPnz59+vTp06dPnz59
+vTp06dPnz59+vTp06dPnz59+vTp06dPnz59+vTp06dPnz59+vTp06dPnz59+vTp06dPnz59+vTp
06fPP0bw4v7rUBkRBiQQAWYVBCDCzICIgOydIgUCLN7owDkHIEQkAojE4pgdgFwED0Jd3CIDKSIl
IkgEIogIACICIgCAiCIAREjEwiwiImQ0EjIKM18cGl/kMgMSIokgiAAgAIqAAAIiKiUsAADMAiAi
wh4UAQAQsQggoACAXBz7nb64DyTxlpRhAE2kwjAwpttuh1EURlGz0cjmsqjIOUdae2u1Ma1WS7w3
Jki7XQAG4f7ZfD62GgXIAL63ydK3vzQKIggAAoJnUZqYBQCBtAiDFwgCSOPRDVtbzWZmoEyeSel8
Pt9tt6NsJpvNLS4u5cslpU233Q4ymbjTKRWKzXa70WiWioVOq5U659t1YR93OuAtIIIIKhBmQhSW
5zf0QCvrPCGy9A4DAEQAAJaXz5N8+WIAA0AA9L3NUwEoAhAQIAAUIARAFEAyKECCGrVROsoMj5LS
Wy7Zi9mCZHMDI2PKRAlQCioKM4wKTLjaaFOmKBQ6j1aFceLDKA8UsCjK5LPZko5y+ZFRiLLFYikq
llJmAmAA8D4ItQAgARIqIgIgFoUovcOcEBCBeodFf9N+KSwIg8jzhhAjiKAHAgwQkZQLlICIdc4B
qGigWAqy+aBQMiZQIhTllpeXxkdHbZzUK7WwVEIWUJoA262uCcJAKRFPICIsSiXWAnM2G7W8dcZk
SAC1NpEJMoO5KMhkM2Ewd+aUUdisrurAsDhwLCjWiUbsfUkC4N5XlpfXvviyPlKYQHoHiwAJKMEA
dUAGkZygRWIhVRzcue+aKF8qD0+0u+nw6HgSp4Km2WzligXrXWqtYy4WCkbEAOogrNRq2UxGEyKL
YmZhhWhtms1mxFk0CoTbNhWBfDZbb7eYIWcCDzI+tSH1PDg61mh2FGn2Ig5IGRbQSgnz2iko0Jf5
e4bOnccMCsAAGTQsmAIlIh4RhkbLuy9fv2t3cWQMg+zs/NK6qQ21Wt0DKUEQJk1eJI6TUi6PLIDg
nFdaJ0mSyWSVFw2iQIS90cqL10p5b0NNChiIOqkPM1ltAjSmyxI3O9li2TKnDBu2bO900zCb94zC
AoAsAiLYO5p7BmBf5u/ZVgZg0AAKiICYTIrIInp8vLR92+jV14djE5jJ1mIblUpJo+4AutZHUaiN
seK9eEOqFEah1s7a2HtEZMdEJN4rcVoYmJEdAGeyUavT1NmI2VGgSSAEtEDdOCHromwkqJrd7mB5
KO2mjFTIFRlpaGQsjmMXx0IkwABCiArxZSXzy9rSRgQtQGsrWlOQ63oHzIUdW0d2XyK5XB0jC5QP
wozW0ulWZs7qai2bz8fdtjAXw1DSrljLhEmr02g2mIWdddaLd+A8iNcASISEKbsolwcUCgyFQbZU
RIZI55QJETFxPkniXKmUWtuq1ccnp1rVaqFQqC4uDg0OdrqtbnW1XluxcdsoYJuECj1L7EVeHlbY
y1pmA6CAAJSgcYAMROXy1L592c0bV7ptDqOEMloFShhtnEcqKDzz3IFQQWBT5byNO/XV5W6jIWkC
SgdhqINQax0FQWgCExixqXiHpIRAKdXudjpx1zN7m6Y2ZSeqMFgYGCwEQb5Q6DjxnskEabuTHxmp
Nlo6taPDw6dPHt++c9v06RODpcLpE0fI26TVIoUaMXGuL/P3cg2gAAJH2gmw1tHo2NQ116nBwUo3
5jBMWQBMLsho8BB3VNodzucWjh1uL82m7ZZtNGy7GWWiUqmYKxQzuRw7l3Q6znlnnbPWeS/iQBhJ
ASESElEul9eBsdbm8vlunHSaraXVigBRFA2PTmTDyIQZC9hptoJMDoEQMFcqLJw9PbZxcmn61MT6
yRPPPKOtbdWrSATC8vJwsLy8N21QiKEASWDKu3atu3xvR7AeO5MrpgyByWjnOUkLoc4HGuN2a3F6
+rkD3cW5TKQnRkfK5ULK3lq7urwSx3Ecx84mL20KIIDA4PCQUjrMRoODg87DzPxiu9HyXnKDQ6Pj
k0JKmAeGRucXFrUmlQkTZ0vlQlJZyhVKq4vztYX5tBOL7UJf5hc82v/Dz1QkoiCbndx3RWnjpppn
q0JQGYVBGGRsnOZBcgqRbW12+sxTj/nVmdF1k6MD5WyAjerK4vJSK41BwDpntEYQEUCR511VXvWc
aSIgwACICKAVKaJunAKAVoBa5XL5fHkgVxxIrVucnu80W7l1U+vWb0hTzuTzlVp1ZN3Y8tKSUmjA
68C4TpcAzhw6BGlbuC/z2oWJAb/9LAgBAYGFkCxoLA9tvf4WVR6pOJEor6KcT13RBL7TwTQei8Q1
K4efeKI9c2J03eT6yXHP6fzc9OrSsvMeFCg2mrQXhyiB0qlNCBERxXsGQAQWcAAIoBBQEzCACCli
ZhQAFiS0IMygs8HAyFixNEigFmbmuq1WbmSiMDYeFQqtSiU7OLhcWRkfGWwuzk2Mjz517zeJkK3v
b9q9304A8rzMRIAI3oFSGhmxPDh1/S3Z4fGlVmoGRhNRiDoQpk5zOBtF6E4+9o3VE4fL+dyWTZvj
TmtuZrpZr3oQIRISIo0SgmfnHcDzkWMBIAiiKJvJlPIUKO98t9NJqnVI0+808zHMhOKd914p49gr
0t66wdGR9VMbatXGzOysN8HA+MTQhvXVam10YvzMkUOX7Ny+/76/tZ0OAsrLxqeNL4tfLufu7wSe
AU0oTnRpYMeNr5Ch0Xo3zQ+NLze7mXwhbrbKgS6QtBfmTz3xsK+c2bxt88Dg0MKZ6YXZGQ1ISFoH
jr0Vlp7LghQEweDwyMjmLXuvvHpwaGRkYmJweDTK52PtJdKRNq7dba7WWquV5vLq4szCgf37Z06c
arXr0l4AAB3lNKCxXtgTYsrslIxNTg6NTcwtLK4sLGRGhsc3b4s77YnxseP7H2tUV5EZnH3ZuLQv
uMx4zovZOywBWRlhMqNjG6+4wuUHkkxZEEkHgJR2ugWtyyGtnDg+/ei38spfundHvbp66ujxNLWB
zmrSzrEOgk6cADgI8ut379x9zTU33frKnbsuzZWH0AQW0Al5L04kEeuRCdEAkUBkggCVWEcC87Nz
Bw8feObpB488/tjMI48DYAYwUADMrCABb8FrZXbu3MmIJ6en49huu/TSpNWaPnEMEcE7BeK9k77M
z+/ZitdCKB4DT6Hk8hNXX1OeWl/xqo3GGBMgarYBu9EoPP7Nv109dnBsct2OnduOPvPE4vJKqLXz
IBSQybAV9mm2NHzDbbff/vrXb7x899j4uAhUm03nGI02YRhEWdJaK6WsoJO1KKcmy76bJil76y0o
lc1GgbjKwsLi4SN3/88/f+r+b3Y7qxq0DpRjBwrAW+f8ts1bsqXimZk5633c6UovkGWdUuTZ9u/N
317NAYIwoNJMWYd66vqb9Ni4i7Jdk5Ega4RdvTKSi7LoT3zznvrxw5dedWUpGz7zxONxp1OMTDO2
PoiQIrYMueIb/sk7X/OWN+/csROVabfSJI0zmcgYnYmCamV5ZXlxcWFhaWlhdWUlXmxi4nUUFgbL
xeGh4ujg6PrJoYkxk8ukwN4LpyDe5cIwH+iD+5+4+9OfuvdLX7SVeZ0peOcDTjVw6llH4fadO5dX
K/Nz8wRIpECQAFMfv0w8nhf4QqUImIEQiDRT4K0M771yfM++hqiu0qYw0Gi0MyQDBjK2e/Tev+3O
n73syr2d6sqpY0cVYERoWaxS3hOY7HVvectb3/uDu/ftszZptVvFsDigiq1m/fSJY0cO7H/80YeO
HX62U11Nug2XxmAtQAigABhQh5kINVFgiiPDG7dvveHGGy+/6rrxLbsxMJVmTQzm8pECfubhhz/5
+3/w3Ne+BqDDgMR2tdYeGAj37NmzsrJy5sy01iEwenYC3ItQ/2OXOUAQQQtCUYatZMamtt38yo4K
XabQTDxqndUaOq2y4WP3fS2ePrFn725O4oPPHYjCUEScdRRGNvVD6zf903/7M7e+/g1CtLK6PD46
hODnj5197KsPPXL/fc889jDYLhkVGczlokBB3GmmaZItDyplbJKwgFJKAbF3aZK2G03LiY6Ku666
5bpX3/6KN941vm3j7MpCrVbbOLYu4+nLn/yLT/ynj9UWT+byhW67hcQAIsJ7917WanWPHTuuVQCA
zqf91QwEEAAxkCUSBCiXt9/yShtkuxCa3EDqsBBFEVvfrCwfenr1uf3XXHtFt7p69Mhh0Bp1IEjW
i6Tp5a++619/+Jcmt+1crqxqrcbKxWPP7v/iZz91z+fv7izVSeuRqQkRaTcbLk2ibIYIUbhYKsbi
nHCgjbcu6XTRMjHb1AakwiAAHSzVGzaNSxPjt771zXe9/e3bdu6Ym5lXnqZG1z375NP/42Mffeyr
X9TZyCcxKSHFPnW7du1MEnvi+EmjA+fT/tkMCigDyoFKCCQyg/v2ju/YWU9FhaV2R/KFcoY5TNvV
00fPPvD1Pfsu1Un76KGDqAhMlIBycQxh5g0//CMf+Lc/00mk2e0MlsqG+c//8GNf+dSfdBeXRibG
IApq9WatXh+ZWFcaGhmcmMwWy5l8UUgnSaLBkbD3bIyOMhmlVLPRWFhaqq+uLq4s22qlAFwsD1Qq
tWa9Prxly5vf9d7ve88P58qlk9Pzg0Njql39+K//4pc++b9UZJAcuxgQOOG9V+xr1BunTp5ExL7M
QIAZMI5UwpzftmPy6mvqSnsTKhXldE45MUk7WTp7/J6/Wb9t01g2OPjMfqNVlwWDbOpFmdx7/93P
v/1972s2m91OZ9Pk5L1f+vIf/savzR18bmRsMB8E7Xajw3Zk3eTl+/aZfKHVjuu15vxKZbXSSOM4
6bRVN0bxLExBoKMgLOSLw0Mj46ND6yYdQlKvzh86tHL6NEJYyhXry9VG3Nh+1fUf+OkP7b7p+vla
ZSCMBrT5o4///if/4GPguwgJCRMLGrV9157VamP+zAmlFDMjIl9Qryee9336hYhSIqRElbfdcLsd
37CilEShUZiL4zFS8crMwa99YaRU3LFh6slHvoUIlsiiQZVRUf6DH/6tO979zpnKQsZAJOmn/uD3
PvXxjw9EmZHxdfPNRhzQ1KYte3btRe8X5+dmjhyeW5iXdv3cYckEyN/+879DA8zlJzZtHtm8pbxl
m6S8cvD4zFPPhSClbObMwozkgh/84L/8/vf/ULvlXRqUB0b/2x//58/85q8qlQauEYA0vZhcaeve
q84efCrttHoL2jl3AcVWF/StEgiUWD+24/LBjdvbaDpIFGq0SeTsAMGJJ74l3fq27dsOH3jaWksE
HIagNKjwxz/862/6vu+bWV3M5zPSav7Hn/3Qlz7xXzdt3ZXNZqdnzw5OTd34qjvKpYFTB4/sf/jh
00/tb1ZrwNzLrEUUQiAUQOzFKzQKIiAiEgIp8dxcWl48eXr6xNm02d2ze/eey3bXm/XZlYXxjRuc
kofv/nyj3rr2+pt0EFWrzdtuuyMleva+r5EGAmGB1Kbe+8l1E8sLcyzCzEqpf6wyIwEA5so7rrwu
ptBFkSUxCjLgci5ZPXV8+emHL7v2ypXZ2ZXl5VDrFIEFWPBdP/n//OCP/OjC0lJ5JNeuLPzy+z+w
/+v3bN51TafbWe20rr7jjquvvfbAIw/v/+b9iyeO2zjGtbQdEXYAHuBcJQbQWhLw899MAFAhKkBC
UEHKtZkzZ04et1q2XbW3MD58dvo0gzJR4cAD9x85fOzGW28eHhquVmo333xLsxs/99gDFGjrPSrq
NmuFQq6Qz9dqNURERO/9hTODLpzMiAQYjOy6rDS5sdJNMZdHTQH4HFupLp1+9KHhoVI+NGdPnjQI
VoCVZmtvfdd7f/Lf/cLCUrVYLC4vnvjlH//Ro489vmX73oXZuaBYesWb3qg0fuUvPjV37EgAiNqg
MIjXhABeeqVv+Px3UQAKQRAQQQhAAYKAsBAqTUp7q0nH3fbS/OyZlYXxLZs2bd++cOqsi9P1U9sP
PfHA0eNHbnv1naSCVrtz4823HD1x8szhAyoIhL0xqlVvTE5ONZtNZr6AGl9wmRFyAxN7r47RqFyh
a11kVCA2L7Zy9EC8MHPJpTtPHz2adLvMIEqzdZuvu+7nPvIfEycA2ifxz/7Iu0/tf3zzpXvmZ+eH
12245VV3TJ8+/eDdX0yada2IXQLsFQqIeJ9Kr/QNXxjpVgAGQAigJzMAIBAgAaIW0WxZUtYaSFy9
PnPy1MDY+DVXX1ddrcXNdq5cPPn0Y88dO3nbq+/SQYRKXXndDd984MH28nyY1eA5TV2apps2bVpY
WDDGXEDD+wLIbIyBc9WIuY2XlLbsiAG9CYQgIMij2JX50w/dv2nbRknb09NzkTJMyqMy5cF/85u/
tWnnrnqtPlAo/vuf/MnDD35t47bNszPzE1u3vOLO1zz04IOHHnoEnEPwLCkQoLCIB2AEAEStlYgQ
AREIAJoIPIDSIGy0EfF47kUQARYG8AwM7IUFkdDJ/JHjnuHWV9954sypTrNaGh46+eQji9Xma9/0
plqzOTQ2NjExdt/dn2cQRUKI7XZ3eHg4DMN6vX4BL1fnW2YiAgBmFmCMciN7r9elsjdB2zsQF7At
EZ585FtkOxs3rDt28IhGsF5ER2ztW//Fj73u+96+tLQ8NTb28d/6rXs/+d+2b9nRqNV1qXjzG+7a
/8RjJ5/Yr0SMpCypEAgCSi848u0YsggQkgmNt6wzhahYVojOpiyMIAyCgAC9gkhxxAKgADSgYgBB
YVyZOxsDX/uqW2emz4r3JswcfuS+3MjIrssuW1mt7rvyytnlheNPPMaA7AWJ0iQZGhqqVCr/eGQG
rY33HhFBeHBi/diuK+qWIRsmbDVKUSu7vDj72INbt21J4vbiwjIRgQq844kdez74S7/sEQNjHn/g
gf/yK784PDxOyrSse+M/ecezzzx1+LGH0cbEqQILa1Y19JJ/5NwHSQGiUkoEwzDz5ne8+6ZX3Qkg
M6dOaaN4re75eWtMQK3ZaRpAARKI1gFFmcXTJ7uarr32uuMHj2aLOQr0A1/9yjWveMX6zZtanc5l
l+/5+t9+NW5USSlFFMdxLpcDgDiOL6DD8bwu5p4lIiJa6fGxcet8N0ktMygMo8Aomj5yxARhsVic
PjOtNXrQAkYE3/0jPzq+bqMA+TT9o//0EW3j4Wz27OLSdXe+bm56/uCDD2HSFbQebArsezdhBsHn
PwiALAhCBJodjI9NRrlCO0knt2wNi0UgJUS9fKXeRwCht4IBBYBBAFDYpUmXovDkt741fXbumpte
2azWhgeKEjf/80d/HSXtxN3hifVveOd7xYkI9nLBlpaWRkdHEXGtUvLilpkQRZiIADHKZAYHh6y1
2XzGgwdk52za6bSmZ0anNrabrW4nRtKKtLPJrutuuf21r1tcXMlEuc/9xafm9z++cXJjbXl+y1VX
QaF47xf+RjvRvfoWDWyACTQArVVfUe9+DEDCgqiS1CGquYWFr37lnny59PBDD9puy52LDcvavUoA
hBhJAAE9kAPwChNJCUXSGNkffPJpMtHWHTtWluZH148deuDe//3n/3NwaLDeat31lreN79gtziqt
RaTT6TBzqVR6vmPCxSxzIBIgKERApYojcWnE5qIUgVAilrJS9VMnIWmPlcvTZ88ohcyMigHxNW9/
TxoVVBQsnDx095/8cbFYjr1AcezGq6549ptf4aRNJN55QHg+9McAGigUZYBIERArLYhsRAKkrC7E
HX/VJbuzNt00Mc5pEuQLBKRBMsABCGqGgAUEQDyIB3bAvpdQJk6cBZDO/LETzzy64/JrJTNmVDYI
zef+68fqCzOOTGli8y1vebso44h6NkG71R4ZnQA0ggEgnWetz+9qFq+FQTyggoGxepCLiVK2kiaR
QMZz9ey0CTM2ieNmGwXY+TSNBzdt33vLrU2PYS57z+c+05yfGRspzy2ubL7iutnDz9VOHwG0zJYR
QRAYwANwT26fQ50zAXhGjSxCAIikMGjEK+ObthSK+d/68AdHNkxlN2xMKxUwGWMyIZmgV88ja/+f
rNXfivdexLO3ACzeBhpPH3xyenZ5z7WvmluojI6UK2dmv/xXnw2CTNPy7a97QzQ64W2KGlGgVqua
IDJRAYMsAKqLWGYGQFSeGZTODg4CgPc+MMYm1ijdqNeTem10ZKTRaHrwLBhkAvFy5U03jI2PGYTK
4tIXP/+5fCGXWFseGhoZGnjm2WeTxKKIc45wzYz/9q9DbIJtpF1mgJQUZYSiruduRu+44cb3/cJP
7bnjlg/++m9effNN/+pnf277dbcwmq7lNgee8uQwZIUvZRoz84HHH5nasG5icsomVgf0pb/8XLtR
T7vtrdu3X3HtteC8CgJE7HS7qU20UeIcEJ1no/u8yiwAjOgBVaGQL5UEUCkVKKWJwsA0V5ag28kV
ct12g0EAQUTImFfeeaezaajx/q98uTVzZmRycm5x8aprrl6Zm1udn1WKlNY9s+67biyMYgNmLYQm
lxlyVqLC4Nv/1U/96T1f/Pnf/2h2MFfvNrLlQd+JhzPF3/uD//wnn/ns2973Y5grdRxkzKjmDL5o
aMc5DsOoPT9z6sihXZfurne6hVJh4djRpx97OB8GaZLeesedYELvmEUQoNlojI+Ngesi4nl2bevz
LLNjB6IzpQEyoQM0KkjTJCDSCqtzMyZQhNhqNgIKLLo0tuPbd192xZUM1sf2q5/7HJlc6iUqlYqD
5UP3PSJitQ68X3to3yUzagQFBIqZWp3Gdbe+7v/5pQ+nZD/1p//tgXvurs/NgF37lyFkNuzaeeNt
d/7T9/3ga97yxo/96m8ceOSRDBoBAvAvskZYGMQeP3TglpuuKw6NJUkXbPP+L33httvvdNbuu+aG
wfWbKiePkEL00qzVB4fGAUiEjUZr5eJczYCKkQAgly94ICskDOCFkDiOba0SRSGh79oOqZ6VQruv
uk7ns47d0szZuUOHh4fHlpeXN+7asVxZmTl7BjFIktQ5t+Y6/a63yotYYeejKHj3D//ob//e7371
b770T1//xi/+lz8KzszsZnNTrnB7ceCu4uhVyLXDT33iD3/rna+7/eCBR//LX3zidT/w/V1IXjxO
ywwiAsSNpdlu3F03tRnQBPn8gQfvryzOMsvw6Lqt23cBgFJaa5UkcbfbzhRL4D2RumhXsxcRJEAK
owwr7QFJiK3PlzNJdRE67XB4SNIUQDwLkAJwl+272iJFOfPYg/elnZYpZwMyQxPrZk/OimvjCw7P
vxvjI4ZAkxMMC8XiaPlnPvRT3/ryXxZA74kGrioPXFoqlzJBgKiEqp30eFx7pL7yRG31d3/2Q88+
+eiGzVvDYpjUOy/uiBZhROFuc2ZmZnxsonPoUCafayycPv7s01ffdheQ2rnvqse+8tfsvELx7J1N
M1HQbYj3ctHKzICIBDqQIAJlAJTzPjCBjRPX7gD7ci7TqKwQgFLKSUqZ8oYdl3bZZwSPP/s0gdVM
XumoWFxcfkIBAuKLPC4SoBQYoLa69Icf+TXwdiNGt45N3jw0vgWpzB5aHaUh0GHH4IbM0CWT48Mn
Dz+4svyNz3xWDJh8vmcf/J83J+y5SIVlcWFh/dadJsxFaBsIj37rgRvueFMntZdcthejgo8bRmsN
ztrUGAVrXecuXi8YAGAQ6EyWgQQJBRRAJgiSeg2AM1HYrNUMgAiL84NjU/mhMVGqVl09deJojoxY
lx8eabu0Wa0gsIh70TgJhZRD0ECM4EaJbizk7hoZvSYy5UYl6FQHiXNJAvVq2GoWWs2pduddO/a8
eWLqklDnEW299RJpmYgIQiIAXJ2fV0F2eHCEbYICx555Ju6mjmVicn2YyQKA7/WGZGdMAIByEV+o
EIFFtNImDL2A9SIsCkgE4rgL3ouws7EAsHgQmJiYCjMFIZpbml+an82byHbjwdHR5WoF4i6BvNSF
RydMLAjIGSV7itHrt23annZK1ZVS4FyQNFw7EeeNgOIi0mSqyrO1O8e2Xabz5VRyL+nCEGAhZCAC
SJJGvZUbGLJpmg1UZXGhWq0oEwaZXG5wEBC0QgZwaRqaAEid5yDG+V3NgMColEGlGZjBJ2ki4tFZ
12yC9+ycUgoABQkAisPlgcESe+7Ummm1EmhKXZyJIunEkFpCwRddbggkgqIBCIoMN4yNbrK+0GxD
u5XYhA0loXKBJhNq0ugYu8mQw+Fm8sp1WzfpSHt5yadDPQ8bAAAuLy8ZY7TGIDTVaqXeqGkThJnM
6Ng4CARhiADOOq01EZ1nN9j5vTcLAzCR4jQR7gp2SgNZTaK98+1ukM0rpRPP9lwzxDBDqNJBVYxn
2uCdz2HT1wdyebfcAmFE/1I91pghBUrB8qYgey0NTtQkwjDJZD1lM+0QQHmUYhvLXQ0CbW1ZJ+W0
syvKbcjk5VyA/EVeJHGu5xEFhGZ1eXSo4HzKCGy7i0vzThwaNTIxBgDtOAaAbhInaYIAcn6TSc7z
apZeaJC9F2Fm2+22nE2FPSMqE9jUWmYk6lV/h4UsAiuhuNUF0GCQkQkQ+VxHuBfFgXdoQZF2MKnM
IAbA0NXYCCkJFIlSHpQIATqC2GA3FKe9sNXCw7m8AsDvtWYCAVA8EwCi0iYA5kaj3utogqTg73Rl
OM/hC31+t2wQUBSYKJPhMGRtIhWpNCV0hOitjeMYQPDcPSmTzSIRi3Q6bQA0yvyDjjQGQSWAFAIM
am1M0DXdTiitQDRjRkHgvUJJNceK2iGkJKGQY0ZF+WIBFv5hhTHMHgCUNkYjcKfRaAACEfYu9Eh0
AeupzrcXDIDFeetckqZd67qc5BGzGth7ItTGAPTuqQgA3jlC8L53+3C05gH5nh8+ihADSwRAnhkk
VZgQemIlDAhaPApa4kSjI4/CxKAIGaTjEw/wD+rVJwJEvQagAMDY6wiM5770BS2/oPP/K3sN8Lxz
zrkwioAQFWFgmCUKQ4UELIgEAGmnK4DCrIwBUEqRPN/D+HvcPUDQeQGoedcBz0oFHrIpRA5IenlE
7AkExXjIWwxiDshYgsV2x/4D91YBUEp571OXAggZjT2njXzX2yAX+WrWSnuPnr1ROgxDymQQDLIn
TWEUtr113iOisO89mqTV6lWmhGEIAM1mM9DGJgkTARCIe/GOiQiASIzcRVm0yQLbHGDOUt6jsFPC
DtmDoPcKoERaJ6mx6HNh3fvZdjN+SUlkrdU+CwBIFAVJknjvA60AKJPNiYhSqtvpAIDW2lpPpMIw
BIGLOkLVGzZgXS85w3tOkq5jDwgqDNlZQsC1jrsCAK1WK0liRMxlMgACREZrm1rSGkAJ4Is/LAIi
RgDhLJ5I0wPN1XYYEoaRU8aiQo1aQ2CU1soTNFOIWUywinI6aS+7VDS91GpeC30iIgDmc4VavWZd
Cgygw6HBQQDx3i+vrABAz/HeS+MF7DmKLlKZPXsB6TXgEuYkTYN8nkXS1GYyGQQITQAAWhkSAIBG
vZEkida6XCoBgCKltW40GqVy6XvZUIU9Wwak1MkK4f3zs9MGKqFqE3EQUCZrkRIvlgFJm1w+zWVX
C9FMnh5cnJ6NYyQDL+GsEkWKRUgRABZLpU6zpQi73U5QKg0NDTFLu9VaXlgAQu+4J3OapgJAF7EX
rJdc6Zidc72aok6nHUShMtoYw9ZZ56IwQuntlri0tFSvN7TWQ6OjJltqNhrKmIXFhZGhYWWMl5cS
AZSAQq9F0Cs5mKafPfnc8Ty0J4cW0a36mIJIoYmdb3quBao2kj9Zpr+aPfZwrQo6JPtSUiA670VA
PGMYZHPZbrebyWQ7HTc0OFgsFgFgaXGxW6uC1r23koi63S47d55rqc73vZmUgjhOul0WCcMgCMPE
ps65XD4PREmclAslz84LE+rq7Ozc7Kxzbnx8fP2WLY1OS2vVbbeV1tliEQDwRRcFKlJBqEkbMI6o
KvJQvfaZo8/cu3C8lQusUXE3Bg9RNo/53DK6pzqrnzx84Our1XmQtrUa9IunFSilRAQBPHO2XCKi
lcoqoAKAkXXjQ0NDAjA3N2/jBER6l0SlNTP3gjgXrQkGwAAWvE9b9WBkXIlJ4zRnMgIsJgs6bMWd
ciHjl0QRMCpO2yvTx7t8S1Aqb9qx9+SBbxkVSNJodBcHxkZnVpcUEMJadH7t2vIC74OAB/He21J5
8EO/+AtPPvX4p//kE1+rdxbt0pPFeOvA8GSQHY4KMdLJ5aUzSf1op/lIq40BvecDPzw6sPGPf/fj
SbuF3zmxgl6wMRGwUUheCUQDpXEQsJ2YvAeAzdt26ZzRmM4cOww2ITQgoEACpeIkPZfJKxenzIgg
YgEwbtVLOrQpBqREMPWQzQ1ArtxstYYKQwiw1mce8MlH7rvtbe/QmbGd+274+l/+WZp6J63l1VPj
m6amD814bhP0DDqkNYNMANaOVEWIkgJQo1F/8MFH/83P/sJll9/w27/xG08unX2y0w6rjQmh4TDq
OFjo1iuQAsD4xh3/+mf+7bXX3/Crv/IrLd8hJBHGF2j8wjUozqEmlhAht3nDzpXFFRJ0KQAEV95w
c4JMneaR/Y+AZ9ARs88oXcrll5aOk0J/fndtOu9HMwJIt92OlGKb9KqKlQlMJjswOtpttZUxmShw
noUIhI88sd92OolPrrjxmlxhbLWyOjU2NX9yplQu5wfLDF4AldJG614W5ndYfM4DIBCqIPzCp//X
j/7Qezdv3fr5L9z9/p/4N3uuvB6MOZ029zeXD3aX03zh+ptf9dO/+Kt/8j//x2Cp+MP/5Ae+9rm/
BOG/e6GS7/wkTixQWMiNjZTnjh/OZ4Ju2h5YN7V9z2XiYfrs2ZOHDoIy4r1GbUKTy+VSZ4XlPJ+W
59cLJhAoSrxP2i1O4lCprveMyiGIpsGx8eqRJ1PmfKnUjJfBOdJBa3H56MHn9tw4NrZpcvu+y566
/zjHnNRa7Xpz3fYNR1ZPAZJnAPTMvfMP4fkApUDPgeasJRUdeuaZ97z97W98w+vf8c53vOUtb0rj
7qn5Oat0IZstlYuZfGbh7MxHPvKbX//Sl8SzVorT+LtCI/ydq5lBYZDh1G+7bNfi/GnfrGUKEbO9
4qYb8qNjoIKjBw83ZmcozEiSWHED5bG5+XkCFAZUvYkJF6kXzDtGBO60KwtzGa2IGQAtS+J8NDIG
2XKj0cqVSr1LdkDGdVrf/OIXRKzX8Ko3vR5Ad2rdodzgM08+uf2yXZmBIaU1CzNLbyzUC18pE5gg
CBCACAVERQG69Av/+5Pv+b63feD9/+zZgweXavWnnth/amXloQPP/osf+qEPvOsdX/vrzwt4QhaX
hH9ffcRa3Q32JNcixoyMjG0cO3P6SJZgdWVBZ7M3vOH1og2n/oGvfRXEATsARsRcIV+priKA0iT+
Ys4eAfZCiJDEreVFA0yIiASIXctRuRwNDi2sVqNsAUijCay1hOrZ+x5Ymjkr4K++5capLZfW6g2t
om6nOzt7dv3mTUyIhICklEZUz4+OQQTnvIiwsIgoTb7bBPEqk1NBeObEsd/7nd999tnDf/5H//3g
s4f/+Jd/Y+nYcYxCCjWyN4oQ5O8mLawdOoS9yCPqECxP7dzaSBrtRiUMsWuTyT2X7776yna7PX38
xFMP3A9I4h0g5HN5EfYiDKKNOc/9ws73vdloEgHwqXRakCbOujRNyQRt68SEhXVTPnHtJB0YHBJr
NamMzlROH37ky18KNRZHR+586/dbllq9nc1kjh969pI9l2RyOSBlwtDzWn6VyLlG6CxJYgHQ29Sl
CSAKMKcxs1dRaXn2TKfW/ulf++jK6dm01VZRljxz4oQltdYDpN7jC8wuASCliIiIUClQyN6FQ4OX
7Ln06LNPBaGuNNsAeNeb3lYuDxeymW9+8a/j6hJpBSDCaalUqNQqiU2QKE6S8xyKPL9JQgDseqEb
alVWbLOez2ZZwDGYKNtM/MjketBmpVKZ2rgBmZkgYQuo7vn0Zzsrq524e/tb3jK26bJWs5HLF5qV
yuLs7PU33SIALExKgUhPF3xenZ4zEgSBEbwm6fVM987qqDB97FR7bvnIY49HUQEsS68Kq/ei4Hef
xAAgIN6zgFCgUQA0XnXDdWeefpq7sZigEbc27b72zd//rk6ttXz29H1//ZlejEbYBUGYzUW1erV3
GOF5D16cb5kRINCEBK5Rba4uGa0AwLGoMGon1pTL5Q2bWsvLOgzLgyPWdj37rM4vHj5w9yf/Il8o
ldZPvedf/pgArszOjgwNPfrww2E2u3vfPp90pZc2imu3ZgT8zhuQKBBkzy5VRoFzo5PrX/uGNzpv
3/2e93IaM6cvGFiAAArwuzO2kEgHgYgIgrBcfvUV5Wwwe/x4BHppcQWCwpv/2b8AlS0H+b/99KeW
zxwkrcV7BB4cHEjTJE5iJJJvP4mL9mzGnmsbhAH86sJCt9MlpVPnnIADsAyTO7YB4PLCYnlwEMOI
Ah2KNyBf+PM/n11YaHh/3Z2vvuLm2123pZxbNzl5/9e/dtm+fZt27gbp1SF/29v9gi4j3BsdqgmN
Ju88hsHS9PTJ2bPZ8eGnThxONaMhMs+PlCUABaLlnLNqrZcYs/MWA8PtZOMl27fu3PLQ/V8rBUGr
VuU43f2aN97x/e/odHjx5PSXPvsZMAg+VQBGUxiYpeXl3n7QewnPc2qnOr8qE4L0kqdQZ1zqwnVT
OltIrANSiiCjIKuxurpSmT6zfsPGtu0mnZZ2Lq+zldrKQhK/4nWvDQB2b916z+f/qlFZypeG4iSd
m5255qab6s1Gc3UVUQEIwblK5TVnk1Dv8RKyAColpNi6prXzywsnjx+KOzUQS0TMvNZUCA0AInh8
fhYp9gaTkaR2bOum62+6+d777pW4i3HcbLSzkxt++qO/pzLlchD93i/9+0NPfl0TKCDPUioVo0xm
eXlFGSUs0Bvm8e2X56KTuRdm7XWJQGFwKWbyw8NDoVYiwuyV0YRQyESN+VkQt26wvLK0pDVZ8Z54
5tjBS7dv27Vpc3lkDMrD+x96rF1ZHh0brdYrjbi17+ab6tVGq7oaoAq0RkJAAWRSuDaXRqMXYQFB
FpcASmtpefn00bhaA2bwyFZACET1NjlENuQYgDQKIZpAB5H3VB6euOG21z777BFfb0LcqbRiS9GP
/ep/uPrGVwREd3/6zz7zh7+dCXQg4gFQqcmp9XPzC9Za7CXGCJz/SaEXbEakAANCWm2t37wZjXLe
k9Fp3C0VCjmtVpYWGguzo4MDCFhvtxyyigLpdo88/cyr7nodBtHuq66fXq6cfuqhbr06vHHD/PT0
ar1x1U03JYmvLq8AKkVICAJstGFmYRAA6b1ivJatRABEhMDAfK4ZjayNpQQP4BGIlBYE0Eas5TTd
fsUVt736NY98877WUtUorFZWrE/f+uM/+dZ3vVtrc/rYod/5lZ9P2w2xsUHoeh6fmAjDcGFhQWv9
d2s2L36ZAQCVRlCW/boNm7pxmsmEQwODqyePrxw5pBHalUo3jrft2jE/vwCE7BijTHNp+eTZuTvv
er3tpjfddMP83MkThw/Frc7GdRvbtdbM2Zlrb7vVFAsrcws2ZWRRRDZ1IICAhsy5o7sXOkACRuHe
9GACRmAEoXMfhWh0waPxgsKiM9Hlt9y4devWe//mboy7Ku2u1mupS974g+//4M/9XKNRY05/5ad+
Yv7pJ3U2ApuCcCaf27hp4/Fjx4nIXdBBghd04quIzuSSdnNkbDyTy9eq1dmDz0m7VRwcRIZQqerK
ks5nxicmlucWlNFsHelg9uiRrpNXvvI2Y9SlN+45ePTg4vFT0vUDQV6h2v/441sv2XnpNVdWa9VW
s8HeEShNRpFh30slpHMfJBB8XvNzBuI5IxiJiDHrXApMI5s33/DaO4nosXvvzQQG07RZXen65NZ3
/fMPfvjDnVYzn4/+wy/+3FNf/RKFhhMbKs0eduzaMT8/32g0LuxShgs/2Nen3jkRaTQanYXFkeFh
0aZTq4wNjTAq226sLC+Ord9gfdpptZGUAKoge+CRb0W54u49u+NydO3td8yfmj9++JBOIGfCoXL5
6JEDrW5jx5W7pjZt6NQ77XbHi2Uh7pnQ2OsMhAIk4PncKl5by+fsNwZgEWYYmFh/5bXXbt+168Cj
j508dDSbzTWqjWq1moC/4x3v+4lf+jXnkmw2+NhHfv2rf/oJlVFinQIGUOPrJpx3s7MzQRD0Mtrg
wuV3XlCZEUJEhVSvVMrF0ujU1ML0bCEKyZhuoxFls6Kp26jVVpa3X3Jpp9Vmkd6dxuQLj3z9G2G+
cMl1N3kMX3PnG5OOPP7Eo61Onb3dMDVRWZ09cfRQkAn27Ll63cZNqZdmtwPeA3gAAqVRa1RIoQFF
2Gs1hCTfzkKDsFAYmVi3c+/le/furiwsPnrvfXkd5YJctdbqNpqQL77tn3/g/R/6d56CTEb/14/9
p8/99z/SAYL34AQACoVieXDo5IljSqH3vreU1yz5f2wyE4IBYGEk5Z1NnV+3bt3C8mKUz+WymVa3
UyjmrUtcJ+524+07ts+cOdMbf41IWqlHH3hA2dxtN99eT9Nr7rw9GBl+7plnmrXZVqOWC81QubC0
MDezUAkCM7V50/Y9u/NDQxhGlMk49uwssBePYlmEQAWgAgyz+UJ5bOOW3Vdes+2Sy8rDI/XmynNP
PrY0N1cKci5NV1drcbxamtr+o//+l9/6I/888VLK6I/84ofv/uOP61CLdQGReM7lcjt2XXLw8BHv
UmaWc1zAzul4QRczZDQ5Fo/agx5fv8mbaGxystlqthr1yc1bFk8dnxwfOXHkcKu6Ojo6NjY89Nxz
zyAFQFopY1Pr0+h1b3v3Oz/043rjcCdtL5449umPfHT/PV8Gm5YMZQZK3aBoCBvtdjmfLwwMjE1O
BkGAiM65JE1tzCBCiKS11joKwzAM643G4uzM6vJq7BOSOBOFmEJrtZn4LkDhVW944zt/4l+N79xu
A12fm/udn/3QU1/9QlAqcdLyaSIMmSi6bO+lR4+eqtWbcG7G1QXnAsscKPKeMQg8E+tg174rV6u1
bKGgAl2r17dt2jh74LnZmRkCYZ9u27alWCzsf/opE0SOQaE2TndcuuWqqz/wqx/ecvU+FGksLD7x
la/+1Z984uzB5wAs6iBbzOcKRQLoxrFNkjAwRmswJpfLBzpkBu9dmqapdeA9W9vqdJTRxXweiKqr
q0mnI8yAtHHfVe/5Z++77TWvESIP+ODDD/3pb//m9NNPaBN6l4SZ0Cax1rRr186Z2dnVlQpqJZ77
MgMhGE2pZSAC1KAMabPzyivbIO1abWRyYunI8dXT09l8PolbyN5xum3rFhWGRw4dRh0orYmdNmGn
1coMjP/A+z/w2rf/QHF0TBBbK9V7/uoL93/+fx/f/0AvG0DpoFgsGW16f3FvUjciKgWEJCLOO0QK
jBGEuNvttFoeGCAHmNu6b9dr3/vOm+96db5UTLsdasd//Wd/8YmP/T63K8UoTNIURIlCINq+Y+fq
6vLS6iIgA4ik0h9pAgiABMxgAuMF2AOFYTYKB6bWD4yPH3j0YW7FRoc26QRBwM4COMe8fsP6DZs2
739yf6fVxAgREFIwGCbebt59zfs//PNbL99ndBAEUbqy+tw3/vbeb3zj2af3L8ycAEh7uSUEJtCB
VkjoEbmXh2u9s56/LUrGjI2s33PZ7Xe84U07r9ldnBjsctLtNJ9+6Fv//aO/M//sMyGFGj2ITZkF
KJcv7br00lOnTy8tzZJWDEwi7OFlwstqGjsiignDTRs3Hz16BASQaK3XeW/1E/VGCYxPjE9OTk6f
Pbu0tKwJiYARRZRngDB/zS2v/IF3veeyK64YHF7HEFYrzcry4oGnnjzy9BPTZ46fPXV8aeYs+ARA
AOLvCKtkotzE+LbtOzZv37Z17+WXXnr5xnW7ozBMO+1Oq/7Mo4/81af+7JF7vwGuFQVZsFZpjL3z
zOvWTZZKxcXFpUpl9eUzlOhlKzMEQWBTKyBKKe65M77rYqB63m8eGBjYtGmjTdpHDh+zDEQoqFAH
7AEYMMxedu11r3zdG3Zec92mTZuyURgak6ZxrbK6urJcrax2O+1unHRbHbZOaR3lsoViOV8ul0eG
soVilM1prQnBt9rTp089dv8D997zlaNPPi5JHcgoBCWsURwCEO3cucN7f/jwYVhrHPOy0/hlJzP1
QkDM+Xy+1Wp91w2kl7nhnAuCwHufyURDgwODg0Nnpmcqq6tKh71+2KhDBoA0BqMLG8Z2XnLJFa+8
/fK9+4qDg4MjE0Emp4OIQTnnwJNCrQmwd2QAiHPdbidux2dOnz526MATD3zluf1PtpeWwMZASikN
4JHZewvApWJpasNUq9U6ffq0MYaIkiSBlyX4cvtCWuteX/W/95bZ8zAgYhRF1jrn/MjIyNat2yqV
1ZmZOe99kiRKGSJ0zoIW8Q4YIMQgyufWrd952RUTUxvHJ9YHpYEwnw9UYJTWBEm301itShzXVlee
eeqpM8eONxaWXKcK0AJUKpNl78F7BBTvRTgTRZPrporF/KkzJ6vVqjFGa50kyYWdKfb/G5kR0Rjj
ve8dw2maftdPtdbMTETWWq0NorY2RtA7tu8oDZSWl+ZnpmetTxUoRNGKRDwQOc8ixAIAHiAAEABN
hSEBKy4GEEgt+OT5bgJreSekVKATa9cGN1gXRlmf+o2bNuVyuYWF+dXKCrPrHcZKKThX9tiX+XtS
+gWhDfn77TSRb8tBGgGEXRjo9ZNT+Vw27naqlVqtuup7ta+kEInPtQFEUoTYa5vcG7wrvdwSAkQC
EJRzXTEQGME6YQEiKBaLw8OjIhB309VqNe62iYj5Zarry13mf9grQebcnyHMHkHy2Wh0eKRYKor3
S7X6SrUtzlnrALxSaBQg+14HAURE0ALEIkCARCzeM8sLii2MokxoBodGsvk8gqxWassrq977MJNz
1nqXvjwNrotMZiDSspYryQKgjUYR65zWaqBcHhlf1zWhtS6JO2mzkXSbcafTyylQvQwgTwLm+XyW
tVcn0lEmG4SRNlQOTahVN44r1Wq73XXO9VJ8RIRIASL7/mo+H8sZzrWkWcvV6o2eQQTudV+OMtls
NpfNUBhkwsB7C+zYeWbPIp5JQCtEJELAMIiCKGOtc9anqeO026gup2kXQBCplzZKCkXYO39uE+mv
5v/rX1i+++sTKaUFgJ2DnuHkv+3ZIkWBCYA0KVLaEBEaFmQRES/ggZ3n1IEHtt4DMwjqEBG9dyJC
iACCBIDMLGtZ/wJ9mf+/+n749xQY49pAT0SRtRFh8HxlDSACEYhHdr3GXCzCAr30sL8rDp37nBtQ
RowoCF48gKCQRkUIwuxAGHmt0K03GZhfsOv3RuSwQgEEYXLwwm5ga0kqai3Zny306dOnT58+ffr0
6dOnT58+ffr06dOnT58+ffr06dOnT58+ffr06dOnT58+ffr06dOnT58+ffr06dOnT58+ffr06dOn
T58+ffr06dOnz/9N/l9JwFG6rpcmzQAAAABJRU5ErkJggg==
EOF

mkdir -p app/src/main/res/mipmap-xhdpi
base64 -d > app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png << 'EOF'
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
NO3YmnUua1yeIwCL6wrxmxbaHCMvIri5rJNSnlICnGVWQLRSI6Oj5b6hxPMQ0dksjeO0XkvajXaj
0fG27ryQHR8HZgDxN29Z5Eteaq11EIRhwQ8CY5SnqKDRKNVO4oWFxUazhZvzSkkpEe6E2s4E9TzP
ukL85hXipiOMyIa7aic3yZsDm7QxjpmtAwTwgqhYqlRKymgyJjDa5pl1GbrOiLuc2Tkn7IjBdIZN
UyfvDVCISp4fWGFgYCfWMggnjbXV5UWRHAAQleeZjfMHbhjFSueCetP1oivEP2M/PZFSClE5tmLt
xnRuo9k6sZtj5z1TCALP94g6Jh+ktSJSSIgamDYn2zJgR9IsnIOzeR7bJInTNGNIAbTxAkR0nLvc
bXQSKEIEUiggNredIxXgneh63RXinzD8fcV3Os13m8vhbRs6AEQF0NGAABEiSp5SZxwLASJmjjtx
ihAZaPPMToiCikF14pkICzCQbEx5QgAFoEARKES0iBZAkIWl04VFiMJiOUcEQO60ZbFz+JXJgNf3
9cttyygQkC93tsE/5u2+w3KQ+M372aIvXdDoy/+ECAEDCknnHq7T5dkxb6DX/goBAALnt5MvG2/9
5iXNhr0xfLklNgFs9k0RAiESgzCgk46LMQhtnLgRUAkgKEIAEQZwIIIsiKAQhIE2R/TwZl5SXufe
KARMKJ06nJw1AwIwoLzuiTvt/x0fCgEQhK9vPmuXLl26dOnSpUuXLl26dOnSpUuXLl26dOnSpUuX
Ll26dOnSpUuXLl26dOnSpUuXLl26dOnSpUuXLl26dOnSpUuXLl26dOnSpUuXLl26dOnSpUuXLl26
dOnSpUuXLl26dOnSpUuXLl26dOnSpUuXLl26dOnSpUuXLl26dOnSpUuXLl26dOnSpUuXr8H/B6pt
NpZokmCyAAAAAElFTkSuQmCC
EOF

mkdir -p app/src/main/res/mipmap-xxhdpi
base64 -d > app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png << 'EOF'
iVBORw0KGgoAAAANSUhEUgAAAUQAAAFECAIAAADQiNCRAADJQ0lEQVR42uz995Nl2XXfC6619t7H
XW/SZ1VWZfmq9t1ANzxICCQlikZ0jyIp8Wlm4mlMzA8TMf/FxLyYHybevDdvHhVyJCVRlEYjShQJ
kgAI0w10o215X5XeXH+P3Xut+eFmmQYoUSIwE0LjfOJGd1ZmVmbde8/3rLX2cgAlJSUlJSUlJSUl
JSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUl
JSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUl
JSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUl
JSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUl
JSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUlJSUfAVT5EvzwgQAIAJqMD6SAAVCBNoAKAAFp9iA/
8MOIGYSBjK/9QARQaWV8BAIhACQ0RnssCEAACEBRUEVUjsHTPgsq0p72EZUIGO0b7YsDrQ0iiUj5
VvxXhS5fgh9aRJwTkMd/gqfVJQLMT/7A7JwTAOCZchEYQQQQiAgZRRiRlFLWOescAjIzCDCwEyYi
5/Dx72LmJ7+35L8aqHwJfkjfOFRKRBCRjJkJFglRKQAAREAEZmaeKVyY2TlgBnbiGIlm77wAMAJq
DYhISEYXzjI7AHDCR7cBETIaCBiYURjBMTOXYi7FXPIDMMmASKQ1EBKRUgoQAQBJEREAIBEQiQgz
CyIAAiIpBUizjx/76wKSOysISCQA1jkAAQBBEQQhAAAkRK0QUQQYAbR66ieUlG52yffrYYtjBhYH
wigACCLMPIunhQVEBNEJoDYigABKG0GSAkSAZaZZBAGcmdmZMbdOBAAJEIEIAIAFABEJAEUEQBEh
owPh8l34r43yAOyHkaMTMHgUwoIc6flIhI8/cO4okBYAAJo54cwIIERHPwMJREARIIIrABC0fvRD
Zr9r5rDz0ffPfp08+qElpZhLvm8xCyChCAKgUkAA7EipIIq4KEgpEwSuKMDlyvO1US5LK9Wq0tpm
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
EOF

mkdir -p app/src/main/res/mipmap-xxxhdpi
base64 -d > app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png << 'EOF'
iVBORw0KGgoAAAANSUhEUgAAAbAAAAGwCAIAAABHLKd9AAEAAElEQVR42uz995ekaXbfB957H/O6
8OlN2e6a7vEGIECCJEhKlCFESYfn7P6Ru2dJSVwdrVaHK5GgSAIgMMD4tuUrfWT41zzm3v3hjayu
6ZkBQS1xhOG+nxNdGR31RlbGG/l+4/oL0NHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR
0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR
0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR
0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR
0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR
0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR
0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR
0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR
0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR8VcQ7E5Bx3+w3yNR
SAq1EmaJEUSACIgAAGL8+eORjDHGSIy+aYQZtDbGIIB3TgCUMcAiMQqziAAIodJKsUiIof0HBRhR
5WnGwlVdE5JWKnBkZq2UJhVFYgwiYowhUsF7ZlZaCXAIAYC7963jS+juFHT8h0REREDk3Ud+6WFf
flyEmfHtN4kRAAHvpG+rovjuBzihQqLIkZnfPu/tHRYBRED84lEAARBhAeneqI5fiupOQcd/IAsR
727SqteXTMKfe0QEERWRAMQYQfgLFRMBZgEABGytS2EAQCKtFCCyCAgjklaKtI4hxhjb40VAWtET
EUStNAAwMxIhITOzsACLdILY0VmIHX+pkoiEpARQJCISKSVxa7shIhJJa/chIqIwg4i0wvdWnto7
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
BFmVZahqJCJjjUmB0AkwCFprjSXmOsTgN05rfXjg1+v15aV59HBweHD59PNqsdxUJRNiaq+m16jp
5PDQmvtPn35alZvscL/XK2Y3N/VmXRYZW6OI6qqKHFWWlHV1e33l64pQXFP7uuIoIswcz89eMzMA
C8vLp5+1c7Yvz94gc13Vxtrnz541dSUcZ9Opa5q6LIN3b169iiJNXZer1a1Wriw1AgFsVqtNuQkx
ZGnKHMtyowit0dHVzjXt/FoUKWdTFfzj9x6L1j/44+871+ycnJBNlrczX1U2sYpwtV6vV6vd/b2j
4+P5fP7q5WtQutjbN0m6mc6q6W3v6HD/vffWTXP+8lW9qXb29u49eIiENzev66rJxjtH9++7crNa
LjgGNAZJIAa1XccamVkAcDtBhwLGGAURlML2fHTXQSeIHXcKKO9WItI7kSZsl9EJIJEhmwhC5AhR
IAQJDjTJeDw8PhqfHGeDAROtQowxirWidIwYGQBRa63JKEVGKas0EUoIoWo25caXJRCOdneXNzfN
9Y1CSopC5blfLFZVWRT5zu7k5vpmNp8dHuybxIS69oo0UZJYAF4u5yZNSFG9Wn38wx96Zo6+WZXT
ctNGOYUjB257e0VYGgfMQAgswK5V/gYYIACIr/VNU4EEAL9ecFVtoqsAwnoaAQAkLoDrau3qimNc
z4mUbpoaiJgDkCCRayrhOJ/NNk1NRYZGu7pumlpbs7O7V5ebsFyMJqP33n9vvV6fPXvqOO5Mxtaa
UFVQllmaDvr969dvYLG0w5HN8sVydVtucNA/ef/9nZ3dl59+ev7iOSi9c3TcGwxfPf389s3ZaDg6
fvRwMBycv3gBIiZJitGoKdfNcs7RG2vTYhSCbzYbFyMLk1IKMUlMZPYhBukGdneC2PELESW4K6yR
7YQ8vPOkgQEBURGhIgoYOQARmUSPR+npyc790+FkHITnq83aOVBkklSURSK6W+YOqIAIlRKiCCLb
OjkCRXmW9JI07u02VbVqKrtZU5ZgYteL+aDI7p0cx6aZz25dXaVWA0dXV6vFwjW1xDCf3khkrstm
dvvq+gK0BWvBOR8cKAPGADDw1vVHQGUUogYRRERIAKHdFQUcAQQBkUhYCdh2aKtWqbCIUkgIzCG6
zaICjgC4uXXb/XwIbrOq1qk2xnuvlZLaucCqyGrf3N5c++htloqw26yxqXZHD+4fH/zgTy8WF2fZ
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
AYGBBMB7BgSuei8XicunE4PVn0qEvGgWr1a4LOreUoWvRIC4MO7+5Txw8un/+R91mzV1hPjfzaP5
aR5QfiaCe7YR+tnbOD8KVuMei9Pv07GPShQqAWEG71AujIUsJ+cEgAWqOkkllFppVLSYxRM8j/wW
+UjG5e8pFyT2gp5fKDLT098aCc+/sFJrXPZz48W5RAfint4JT7vHq0CYFq3esGiy8ezhYpcQAwEh
VX/7wj8RPqb3+2O0SD7pmrt49148gvPHfLF8iisYl4/Uhx9agHq+sI4Q/7fykoV/X4xHnyiI+Ey+
8GL+kBZXOX70pqXqtpOPSO35DSxmkUUQ4ELh5Xw45fyDc+uEKhJz7PHCpF6lhOft2R++/uXDf8oF
EYTzfVPng8vnUirLKHRxcF4qIMP5HMvCbqLSPxJGwYumF8vkJjJcmH0RkKUxRWUrBMCA8nNU+5lX
IvqQjCEAAp/3ly/mzJ+6P5I88/CdD/PgRwQR8cKHSwuPp78GAgD4WhBrQawj+o+cpPDZW8RPDEHw
2bgRn/06uWBYIx9z+cvH/OKLYFA+4W+qBEngqQnO+WcWtZWn1zoCENDi4pelVD09ki9KJB9TDD7/
g3j5QxclnA/dB0+tIRZCgmphoi3y4dCcLogof9y9iR/7YOLCnVvOP172GMHSxgI/xXPh4u8g53H1
xfud6hNhTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1N
TU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1N
TU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1N
TU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1N
TU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1N
TU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1N
TU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1N
TU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1N
TU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTc2vNf9/Uf0+IVNE3tgAAAAASUVORK5CYII=
EOF

echo ""
echo "Yeni proje yazildi. GitHub'a gonderiliyor..."
git add -A
git commit -m "Sifirdan temiz surum"
git push
echo ""
echo "BITTI. Actions sekmesinde Build APK bitince jarvis-apk dosyasini indir."
