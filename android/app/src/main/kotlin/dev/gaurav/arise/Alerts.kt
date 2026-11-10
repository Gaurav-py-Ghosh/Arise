package dev.gaurav.arise

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/** The System's voice outside the app: notifications and the overlay window. */
object Alerts {
    const val CH_ALERT = "arise_alerts"
    const val CH_FOCUS = "arise_focus"
    const val EXTRA_ALERT = "arise_alert"
    private const val ID_ALERT = 1001
    const val ID_FOCUS = 1002

    private const val BLUE = 0xFF3DA9FF.toInt()
    private const val RED = 0xFFFF4D5E.toInt()
    private const val BG = 0xF505070D.toInt()

    private var overlay: View? = null

    fun ensureChannels(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CH_ALERT, "System alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Deviation warnings from the System"
                enableLights(true)
                lightColor = BLUE
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 120, 80, 120, 80, 400)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_FOCUS, "Focus timer", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Running quest timer"
                setShowBadge(false)
            }
        )
    }

    private fun openApp(ctx: Context, alert: String?, requestCode: Int): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (alert != null) putExtra(EXTRA_ALERT, alert)
        }
        return PendingIntent.getActivity(
            ctx, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Heads-up notification with the full explanation; optional overlay. */
    fun alert(ctx: Context, title: String, summary: String, body: String, danger: Boolean, overlayToo: Boolean) {
        ensureChannels(ctx)
        val full = "$title\n\n$body"
        val n = Notification.Builder(ctx, CH_ALERT)
            .setSmallIcon(R.drawable.ic_system)
            .setColor(if (danger) RED else BLUE)
            .setContentTitle(title)
            .setContentText(summary)
            .setStyle(Notification.BigTextStyle().bigText(body).setSummaryText("SYSTEM"))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(openApp(ctx, full, 1))
            .addAction(
                Notification.Action.Builder(null, "RETURN TO QUEST", openApp(ctx, null, 2)).build()
            )
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(ID_ALERT, n)
        if (overlayToo && Settings.canDrawOverlays(ctx)) {
            Handler(Looper.getMainLooper()).post { showOverlay(ctx.applicationContext, title, body, danger) }
        }
    }

    /** Ongoing timer; asks to be a Live Update (status bar chip) on Android 16+. */
    fun focus(ctx: Context, title: String?, startedMs: Long) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (title == null) {
            nm.cancel(ID_FOCUS)
            return
        }
        ensureChannels(ctx)
        val b = Notification.Builder(ctx, CH_FOCUS)
            .setSmallIcon(R.drawable.ic_system)
            .setColor(BLUE)
            .setContentTitle("QUEST IN PROGRESS")
            .setContentText(title)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setWhen(startedMs)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setContentIntent(openApp(ctx, null, 3))
        b.extras.putBoolean("android.requestPromotedOngoing", true)
        nm.notify(ID_FOCUS, b.build())
    }

    private fun dp(ctx: Context, v: Int) = (v * ctx.resources.displayMetrics.density).toInt()

    private fun label(ctx: Context, text: String, size: Float, color: Int, bold: Boolean) =
        TextView(ctx).apply {
            this.text = text
            textSize = size
            setTextColor(color)
            typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
            letterSpacing = if (bold) 0.12f else 0.02f
        }

    private fun button(ctx: Context, text: String, color: Int, onTap: () -> Unit) =
        label(ctx, text, 13f, color, true).apply {
            gravity = Gravity.CENTER
            setPadding(dp(ctx, 12), dp(ctx, 12), dp(ctx, 12), dp(ctx, 12))
            background = GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                setStroke(dp(ctx, 1), color)
            }
            setOnClickListener { onTap() }
        }

    private fun dismissOverlay(ctx: Context) {
        val v = overlay ?: return
        overlay = null
        try {
            (ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (_: Exception) {
        }
    }

    private fun showOverlay(ctx: Context, title: String, body: String, danger: Boolean) {
        dismissOverlay(ctx)
        val accent = if (danger) RED else BLUE
        val panel = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(ctx, 20), dp(ctx, 20), dp(ctx, 20), dp(ctx, 16))
            background = GradientDrawable().apply {
                setColor(BG)
                setStroke(dp(ctx, 2), accent)
            }
            addView(label(ctx, "[ SYSTEM ]", 12f, accent, true))
            addView(label(ctx, title, 17f, Color.WHITE, true).apply {
                setPadding(0, dp(ctx, 10), 0, dp(ctx, 10))
            })
            addView(label(ctx, body, 13f, 0xFFC9D6E8.toInt(), false).apply {
                setLineSpacing(dp(ctx, 3).toFloat(), 1f)
            })
            val gap = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(ctx, 14) }
            addView(button(ctx, "RETURN TO QUEST", accent) {
                dismissOverlay(ctx)
                ctx.startActivity(
                    Intent(ctx, MainActivity::class.java).addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                )
            }, gap)
            addView(button(ctx, "DISMISS", 0xFF7C8AA0.toInt()) { dismissOverlay(ctx) },
                LinearLayout.LayoutParams(gap).apply { topMargin = dp(ctx, 8) })
        }
        val params = WindowManager.LayoutParams(
            ctx.resources.displayMetrics.widthPixels - dp(ctx, 48),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_DIM_BEHIND,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            dimAmount = 0.7f
        }
        try {
            (ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(panel, params)
            overlay = panel
            // Never leave a window stuck on screen.
            Handler(Looper.getMainLooper()).postDelayed({ if (overlay === panel) dismissOverlay(ctx) }, 45_000)
        } catch (_: Exception) {
        }
    }
}
