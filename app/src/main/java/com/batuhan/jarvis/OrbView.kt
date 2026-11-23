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
