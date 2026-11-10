package dev.gaurav.arise

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Process

/** Foreground time per app, computed from raw usage events for accuracy. */
object Usage {
    fun hasAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = ops.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Package -> milliseconds in the foreground between [start] and [end]. */
    fun foregroundMs(ctx: Context, start: Long, end: Long): Map<String, Long> {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(start, end) ?: return emptyMap()
        val open = HashMap<String, Long>()      // "pkg/class" -> resume time
        val seen = HashSet<String>()            // packages with any event so far
        val total = HashMap<String, Long>()
        val e = UsageEvents.Event()

        fun add(pkg: String, ms: Long) {
            if (ms > 0) total[pkg] = (total[pkg] ?: 0L) + ms
        }

        fun closeAll(at: Long) {
            for ((key, since) in open) add(key.substringBefore('/'), at - since)
            open.clear()
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val pkg = e.packageName ?: continue
            val key = pkg + "/" + (e.className ?: "")
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (!open.containsKey(key)) open[key] = e.timeStamp
                    seen.add(pkg)
                }
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    val since = open.remove(key)
                    if (since != null) {
                        add(pkg, e.timeStamp - since)
                    } else if (seen.add(pkg) && e.eventType == UsageEvents.Event.ACTIVITY_PAUSED) {
                        // Was already in the foreground when the window began.
                        add(pkg, e.timeStamp - start)
                    }
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.DEVICE_SHUTDOWN -> closeAll(e.timeStamp)
            }
        }
        closeAll(minOf(end, System.currentTimeMillis()))
        total.remove(ctx.packageName)
        return total
    }

    /** Label and Android app category for a package; falls back to the id. */
    fun describe(pm: PackageManager, pkg: String): Pair<String, Int> = try {
        val ai = pm.getApplicationInfo(pkg, 0)
        Pair(pm.getApplicationLabel(ai).toString(), ai.category)
    } catch (_: PackageManager.NameNotFoundException) {
        Pair(pkg, -1)
    }
}
