package com.batuhan.jarvis

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.graphics.Region
import android.graphics.Shader
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Yuvarlak arayüzün yerine geçen insan silüeti.
 *
 * - Gözü yok. Yüzde ve gövdede sinir ağı, devre yolları, dalga formları ve reaktör halkası var.
 * - DÜŞÜNÜYOR: ağ hızlı titreşir, tarama çizgisi iner, silüet sabit durur.
 * - KONUŞUYOR: ağız harflere göre açılıp kapanır, dalgalar ve gövde konuşmayla birlikte hareket eder.
 *
 * Kullanım:
 *   ai.state = HumanAiView.State.THINKING
 *   ai.startSpeech(metin)          // konuşma başlarken
 *   ai.syncToChar(start)           // TTS onRangeStart içinde (isteğe bağlı, kaymayı düzeltir)
 *   ai.stopSpeech()                // TTS onDone / onError içinde
 */
class HumanAiView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    enum class State { IDLE, LISTENING, THINKING, SPEAKING }

    var state: State = State.IDLE

    var accent: Int = CYAN
        set(value) {
            field = value
            invalidate()
        }

    /** Ultron modu: renk kırmızıya döner. */
    var ultron: Boolean = false
        set(value) {
            field = value
            accent = if (value) RED else CYAN
        }

    // ---- geometri (tasarım uzayı 100 x 130) ----
    private val body = Path()
    private val fit = Matrix()
    private var nodePts = FloatArray(0)
    private var edgePts = FloatArray(0)
    private var litPts = FloatArray(0)
    private var sigPts = FloatArray(0)
    private var edgeCount = 0
    private val traces = ArrayList<Path>()
    private val traceMeasures = ArrayList<PathMeasure>()
    private val pos = FloatArray(2)
    private val mouthPath = Path()
    private val wavePath = Path()
    private val arcRect = RectF(50f - 23f, 28f - 23f, 50f + 23f, 28f + 23f)

    // ---- boyalar ----
    private val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#E6050A10")
    }
    private val gradPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val dots = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 0.5f
        pathEffect = DashPathEffect(floatArrayOf(2.2f, 1.4f), 0f)
    }
    private val solid = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private var shaderAccent = 0

    // ---- animasyon durumu ----
    private var last = 0L
    private var time = 0f
    private var mouthOpen = 0f
    private var mouthWide = 1f
    private var energy = 0.15f
    private var waveAmp = 0.3f
    private var move = 0f
    private var sway = 0f
    private var bob = 0f

    // ---- harf -> ağız zaman çizelgesi ----
    private var starts = FloatArray(0)
    private var vOpen = FloatArray(0)
    private var vWide = FloatArray(0)
    private var totalMs = 0f
    private var vIdx = 0
    private var speechClock = 0f
    private var speechRate = 1f

    init {
        buildBody()
        buildMesh()
        buildTraces()
    }

    // ------------------------------------------------------------------
    // Genel API
    // ------------------------------------------------------------------

    fun startSpeech(text: String, rate: Float = 1f) {
        buildTimeline(text)
        speechRate = rate.coerceIn(0.5f, 2.5f)
        speechClock = 0f
        vIdx = 0
        state = State.SPEAKING
    }

    /** TTS onRangeStart içinden çağır: ağzı okunan harfe hizalar. */
    fun syncToChar(index: Int) {
        if (starts.isEmpty()) return
        vIdx = index.coerceIn(0, starts.size - 1)
        speechClock = starts[vIdx]
    }

    fun stopSpeech() {
        if (state == State.SPEAKING) state = State.IDLE
    }

    // ------------------------------------------------------------------
    // Kurulum
    // ------------------------------------------------------------------

    private fun buildBody() {
        body.moveTo(50f, 9f)
        body.cubicTo(60f, 9f, 66f, 17f, 66f, 28f)
        body.cubicTo(66f, 37f, 61f, 44f, 57f, 48f)
        body.lineTo(57f, 54f)
        body.cubicTo(57f, 60f, 80f, 60f, 90f, 72f)
        body.cubicTo(96f, 78f, 98f, 100f, 98f, 130f)
        body.lineTo(2f, 130f)
        body.cubicTo(2f, 100f, 4f, 78f, 10f, 72f)
        body.cubicTo(20f, 60f, 43f, 60f, 43f, 54f)
        body.lineTo(43f, 48f)
        body.cubicTo(39f, 44f, 34f, 37f, 34f, 28f)
        body.cubicTo(34f, 17f, 40f, 9f, 50f, 9f)
        body.close()
    }

    private fun buildMesh() {
        val region = Region()
        region.setPath(body, Region(0, 0, 100, 130))
        val rnd = Random(7)
        val pts = ArrayList<FloatArray>()

        fun scatter(count: Int, x0: Float, y0: Float, x1: Float, y1: Float, minD: Float) {
            var made = 0
            var tries = 0
            while (made < count && tries < 9000) {
                tries++
                val x = x0 + rnd.nextFloat() * (x1 - x0)
                val y = y0 + rnd.nextFloat() * (y1 - y0)
                if (!region.contains(x.toInt(), y.toInt())) continue
                if (pts.any { hypot(it[0] - x, it[1] - y) < minD }) continue
                pts.add(floatArrayOf(x, y))
                made++
            }
        }
        scatter(34, 34f, 9f, 66f, 49f, 4.2f)     // kafa: yoğun ağ
        scatter(45, 2f, 50f, 98f, 130f, 8f)      // gövde

        val seen = HashSet<Long>()
        val e = ArrayList<Float>()
        for (i in pts.indices) {
            val near = pts.indices
                .filter { it != i }
                .sortedBy { hypot(pts[it][0] - pts[i][0], pts[it][1] - pts[i][1]) }
                .take(3)
            for (j in near) {
                val d = hypot(pts[j][0] - pts[i][0], pts[j][1] - pts[i][1])
                if (d > 17f) continue
                val key = minOf(i, j).toLong() * 1000L + maxOf(i, j)
                if (seen.add(key)) {
                    e.add(pts[i][0]); e.add(pts[i][1]); e.add(pts[j][0]); e.add(pts[j][1])
                }
            }
        }
        edgePts = e.toFloatArray()
        edgeCount = edgePts.size / 4
        nodePts = FloatArray(pts.size * 2)
        for (i in pts.indices) {
            nodePts[2 * i] = pts[i][0]
            nodePts[2 * i + 1] = pts[i][1]
        }
        litPts = FloatArray(nodePts.size)
        sigPts = FloatArray(edgeCount * 2)
    }

    private fun buildTraces() {
        val rnd = Random(21)
        repeat(18) {
            var x = 8f + rnd.nextFloat() * 84f
            var y = 66f + rnd.nextFloat() * 60f
            val p = Path()
            p.moveTo(x, y)
            var horiz = rnd.nextBoolean()
            repeat(4) {
                val len = 6f + rnd.nextFloat() * 16f
                val dir = if (rnd.nextBoolean()) 1f else -1f
                if (horiz) x += len * dir else y += len * dir
                p.lineTo(x, y)
                horiz = !horiz
            }
            traces.add(p)
            traceMeasures.add(PathMeasure(p, false))
        }
    }

    // Türkçe harf -> (ağız açıklığı, genişlik, süre ms)
    private fun visemeFor(c: Char): Triple<Float, Float, Float> = when (c) {
        'a' -> Triple(1.00f, 1.00f, 95f)
        'e' -> Triple(0.70f, 1.15f, 90f)
        'ı' -> Triple(0.35f, 0.90f, 80f)
        'i' -> Triple(0.40f, 1.20f, 80f)
        'o' -> Triple(0.70f, 0.65f, 95f)
        'ö' -> Triple(0.55f, 0.60f, 90f)
        'u' -> Triple(0.45f, 0.55f, 90f)
        'ü' -> Triple(0.45f, 0.55f, 90f)
        'm', 'b', 'p' -> Triple(0.00f, 0.90f, 70f)
        'f', 'v' -> Triple(0.12f, 1.00f, 65f)
        ' ' -> Triple(0.05f, 1.00f, 70f)
        '.', ',', '!', '?', ';', ':', '\n' -> Triple(0.00f, 1.00f, 220f)
        else -> if (c.isLetter()) Triple(0.25f, 1.00f, 55f) else Triple(0.10f, 1.00f, 40f)
    }

    private fun buildTimeline(text: String) {
        val t = text.lowercase(Locale("tr", "TR"))
        val n = t.length
        starts = FloatArray(n)
        vOpen = FloatArray(n)
        vWide = FloatArray(n)
        var acc = 0f
        for (i in 0 until n) {
            val v = visemeFor(t[i])
            starts[i] = acc
            vOpen[i] = v.first
            vWide[i] = v.second
            acc += v.third
        }
        totalMs = acc
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        val s = min(w / 100f, h / 130f) * 0.96f
        fit.reset()
        fit.setScale(s, s)
        fit.postTranslate((w - 100f * s) / 2f, (h - 130f * s) / 2f)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        last = 0L
    }

    // ------------------------------------------------------------------
    // Animasyon adımı
    // ------------------------------------------------------------------

    private fun step(dt: Float) {
        time = (time + dt) % 1_000_000f

        var tOpen = 0f
        var tWide = 1f
        if (state == State.SPEAKING) {
            speechClock += dt * speechRate
            val n = starts.size
            if (n == 0 || speechClock >= totalMs) {
                // metin bitti ama TTS sürüyor: hafif mırıldanma hareketi
                tOpen = 0.30f + 0.20f * sin(time / 85f)
            } else {
                while (vIdx + 1 < n && starts[vIdx + 1] <= speechClock) vIdx++
                tOpen = vOpen[vIdx]
                tWide = vWide[vIdx]
            }
        }
        val k = min(1f, dt / 55f)
        mouthOpen += (tOpen - mouthOpen) * k
        mouthWide += (tWide - mouthWide) * k

        val tAmp = when (state) {
            State.SPEAKING -> 0.4f + 2.8f * mouthOpen
            State.THINKING -> 1.6f + 0.8f * sin(time / 70f)
            State.LISTENING -> 0.9f + 0.5f * sin(time / 150f)
            State.IDLE -> 0.3f
        }
        waveAmp += (tAmp - waveAmp) * min(1f, dt / 90f)

        val tEn = when (state) {
            State.SPEAKING -> 0.3f + 0.7f * mouthOpen
            State.THINKING -> 0.9f
            State.LISTENING -> 0.5f
            State.IDLE -> 0.15f
        }
        energy += (tEn - energy) * min(1f, dt / 140f)

        // gövde hareketi yalnızca konuşurken
        val tMove = if (state == State.SPEAKING) 1f else 0f
        move += (tMove - move) * min(1f, dt / 250f)
        sway = sin(time / 520f) * 0.9f * move * (0.4f + mouthOpen)
        bob = mouthOpen * 1.1f * move
    }

    // ------------------------------------------------------------------
    // Çizim
    // ------------------------------------------------------------------

    private fun a(color: Int, alpha: Float): Int =
        (color and 0x00FFFFFF) or ((alpha.coerceIn(0f, 1f) * 255f).toInt() shl 24)

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val dt = if (last == 0L) 16f else (now - last).coerceAtMost(50L).toFloat()
        last = now
        step(dt)

        if (shaderAccent != accent) {
            gradPaint.shader = LinearGradient(
                0f, 0f, 0f, 130f,
                a(accent, 0.22f), a(accent, 0.04f), Shader.TileMode.CLAMP
            )
            shaderAccent = accent
        }

        canvas.save()
        canvas.concat(fit)
        canvas.translate(0f, -bob)
        canvas.rotate(sway, 50f, 130f)

        drawHalo(canvas)

        canvas.drawPath(body, basePaint)
        canvas.save()
        canvas.clipPath(body)
        canvas.drawPath(body, gradPaint)
        drawTraces(canvas)
        drawMesh(canvas)
        drawWaves(canvas)
        drawReactor(canvas)
        if (state == State.THINKING) drawScan(canvas)
        canvas.restore()

        line.strokeWidth = 2.2f
        line.color = a(accent, 0.18f)
        canvas.drawPath(body, line)
        line.strokeWidth = 0.6f
        line.color = a(accent, 0.90f)
        canvas.drawPath(body, line)

        drawMouth(canvas)

        canvas.restore()
        postInvalidateOnAnimation()
    }

    private fun drawHalo(c: Canvas) {
        val cx = 50f
        val cy = 28f
        line.strokeWidth = 0.4f
        line.color = a(accent, 0.22f + 0.25f * energy)
        c.save()
        c.rotate(time / 60f * (0.5f + energy), cx, cy)
        for (i in 0 until 48) {
            val ang = i * (2.0 * PI / 48.0)
            val r1 = 25f
            val r2 = if (i % 4 == 0) 28f else 26.5f
            c.drawLine(
                cx + r1 * cos(ang).toFloat(), cy + r1 * sin(ang).toFloat(),
                cx + r2 * cos(ang).toFloat(), cy + r2 * sin(ang).toFloat(), line
            )
        }
        c.restore()

        line.strokeWidth = 0.7f
        line.color = a(accent, 0.45f + 0.3f * energy)
        c.save()
        c.rotate(-time / 90f, cx, cy)
        c.drawArc(arcRect, 0f, 70f, false, line)
        c.drawArc(arcRect, 120f, 50f, false, line)
        c.drawArc(arcRect, 230f, 80f, false, line)
        c.restore()
    }

    private fun drawTraces(c: Canvas) {
        line.strokeWidth = 0.3f
        line.color = a(accent, 0.20f)
        for (p in traces) c.drawPath(p, line)

        dots.strokeWidth = 1.6f
        dots.color = a(Color.WHITE, 0.85f)
        val sp = if (state == State.THINKING) 0.045f else 0.016f + 0.03f * energy
        for (k in traces.indices) {
            val m = traceMeasures[k]
            val len = m.length
            if (len <= 0f) continue
            val d = (time * sp + k * 13.7f) % len
            if (m.getPosTan(d, pos, null)) c.drawPoint(pos[0], pos[1], dots)
        }
    }

    private fun drawMesh(c: Canvas) {
        line.strokeWidth = 0.28f
        line.color = a(accent, 0.16f + 0.22f * energy)
        c.drawLines(edgePts, line)

        dots.strokeWidth = 1.1f
        dots.color = a(accent, 0.55f)
        c.drawPoints(nodePts, dots)

        // parlayan düğümler
        val period = if (state == State.THINKING) 110f else 260f
        val tick = (time / period).toInt()
        var n = 0
        for (i in 0 until nodePts.size / 2) {
            if ((i + tick) % 5 == 0) {
                litPts[n++] = nodePts[2 * i]
                litPts[n++] = nodePts[2 * i + 1]
            }
        }
        dots.strokeWidth = 3.2f
        dots.color = a(accent, 0.20f + 0.2f * energy)
        c.drawPoints(litPts, 0, n, dots)
        dots.strokeWidth = 1.7f
        dots.color = a(Color.WHITE, 0.9f)
        c.drawPoints(litPts, 0, n, dots)

        // kenarlar boyunca akan sinyaller
        val speed = if (state == State.THINKING) 1f / 380f else 1f / 1400f + 0.0008f * energy
        var s = 0
        for (k in 0 until edgeCount) {
            if (k % 3 != 0) continue
            val ph = (time * speed + k * 0.173f) % 1f
            val b = k * 4
            sigPts[s++] = edgePts[b] + (edgePts[b + 2] - edgePts[b]) * ph
            sigPts[s++] = edgePts[b + 1] + (edgePts[b + 3] - edgePts[b + 1]) * ph
        }
        dots.strokeWidth = 1.5f
        dots.color = a(accent, 0.95f)
        c.drawPoints(sigPts, 0, s, dots)
    }

    // Göz yerine: yüzün üstünde konuşmayla titreşen dalga formları
    private fun drawWaves(c: Canvas) {
        for (k in 0 until 4) {
            val y0 = 15f + k * 5f
            wavePath.reset()
            var x = 30f
            wavePath.moveTo(x, y0)
            while (x <= 70f) {
                val env = sin(PI * (x - 30.0) / 40.0).toFloat()
                val yy = y0 + waveAmp * env * sin(x * 0.45f + time * 0.004f * (k + 1))
                wavePath.lineTo(x, yy)
                x += 1.2f
            }
            line.strokeWidth = 0.45f
            line.color = a(accent, 0.35f + 0.4f * energy)
            c.drawPath(wavePath, line)
        }
    }

    private fun drawReactor(c: Canvas) {
        val cx = 50f
        val cy = 96f
        ring.color = a(accent, 0.55f)
        c.save(); c.rotate(time / 35f, cx, cy); c.drawCircle(cx, cy, 8f, ring); c.restore()
        ring.color = a(accent, 0.35f)
        c.save(); c.rotate(-time / 55f, cx, cy); c.drawCircle(cx, cy, 12.5f, ring); c.restore()
        solid.color = a(accent, 0.10f + 0.22f * energy)
        c.drawCircle(cx, cy, 6f + 2.5f * energy, solid)
        solid.color = a(Color.WHITE, 0.85f)
        c.drawCircle(cx, cy, 1.4f + 1.1f * energy, solid)
    }

    private fun drawScan(c: Canvas) {
        val y = (time / 7f) % 160f - 15f
        for (i in 0 until 7) {
            solid.color = a(accent, 0.30f * (1f - i / 7f))
            c.drawRect(0f, y - i * 1.2f - 0.8f, 100f, y - i * 1.2f, solid)
        }
    }

    private fun drawMouth(c: Canvas) {
        val cx = 50f
        val cy = 39f
        val hw = 6f * mouthWide
        val upCtrl = cy - 2f * (mouthOpen * 1.8f)
        val dnCtrl = cy + 2f * (mouthOpen * 4.4f)

        mouthPath.reset()
        mouthPath.moveTo(cx - hw, cy)
        mouthPath.quadTo(cx, upCtrl, cx + hw, cy)
        mouthPath.quadTo(cx, dnCtrl, cx - hw, cy)
        mouthPath.close()

        solid.color = a(Color.BLACK, 0.85f)
        c.drawPath(mouthPath, solid)
        solid.color = a(accent, 0.15f + 0.30f * mouthOpen)
        c.drawPath(mouthPath, solid)

        line.strokeWidth = 2.4f
        line.color = a(accent, 0.18f)
        c.drawPath(mouthPath, line)
        line.strokeWidth = 0.7f
        line.color = a(accent, 0.95f)
        c.drawPath(mouthPath, line)
    }

    companion object {
        private val CYAN = Color.parseColor("#00E5FF")
        private val RED = Color.parseColor("#FF2A2A")
    }
}
