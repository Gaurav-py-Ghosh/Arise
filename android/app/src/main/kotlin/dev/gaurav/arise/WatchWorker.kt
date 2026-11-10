package dev.gaurav.arise

import android.content.Context
import android.content.pm.ApplicationInfo
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Runs about every 15 minutes without starting Flutter. Compares today's
 * time in distracting apps with the budget the app last saved, and raises
 * a System alert when the Player is off the plan.
 */
class WatchWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    override fun doWork(): Result {
        try {
            check(applicationContext, force = false)
        } catch (_: Exception) {
        }
        return Result.success()
    }

    companion object {
        private const val PREFS = "arise_watch"
        private const val WORK = "arise_watch"
        /** Minutes of extra distraction before the System speaks again. */
        private const val REPEAT_EVERY_MIN = 15

        fun saveConfig(ctx: Context, map: Map<*, *>) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("config", JSONObject(map).toString()).apply()
        }

        fun schedule(ctx: Context) {
            val req = PeriodicWorkRequestBuilder<WatchWorker>(15, TimeUnit.MINUTES).build()
            WorkManager.getInstance(ctx)
                .enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.KEEP, req)
        }

        private fun fmt(min: Long): String =
            if (min < 60) "${min}m" else if (min % 60 == 0L) "${min / 60}h" else "${min / 60}h ${min % 60}m"

        private fun strings(a: JSONArray?): Set<String> {
            val out = HashSet<String>()
            if (a != null) for (i in 0 until a.length()) out.add(a.getString(i))
            return out
        }

        /** [force] ignores the "already said this" memory; used by the test button. */
        fun check(ctx: Context, force: Boolean): Boolean {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val cfg = JSONObject(prefs.getString("config", null) ?: return false)
            val pending = cfg.optInt("pending", 0)
            val budget = cfg.optInt("budgetMin", 45).toLong()
            if ((pending == 0 && !force) || !Usage.hasAccess(ctx)) return false

            val cal = Calendar.getInstance()
            val now = cal.timeInMillis
            val dayKey = cal.get(Calendar.YEAR) * 10000 + (cal.get(Calendar.MONTH) + 1) * 100 +
                cal.get(Calendar.DAY_OF_MONTH)
            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)

            val distracting = strings(cfg.optJSONArray("distracting"))
            val cleared = strings(cfg.optJSONArray("cleared"))
            val pm = ctx.packageManager
            val offenders = ArrayList<Pair<String, Long>>()
            var totalMs = 0L
            for ((pkg, ms) in Usage.foregroundMs(ctx, cal.timeInMillis, now)) {
                if (cleared.contains(pkg)) continue
                val (label, category) = Usage.describe(pm, pkg)
                val bad = distracting.contains(pkg) ||
                    category == ApplicationInfo.CATEGORY_GAME ||
                    category == ApplicationInfo.CATEGORY_SOCIAL ||
                    category == ApplicationInfo.CATEGORY_VIDEO
                if (bad) {
                    totalMs += ms
                    offenders.add(Pair(label, ms / 60000))
                }
            }
            val minutes = totalMs / 60000
            offenders.sortByDescending { it.second }

            // Memory of what was already said today.
            if (prefs.getInt("stateDay", 0) != dayKey) {
                prefs.edit().putInt("stateDay", dayKey).putLong("lastAlertMin", -1)
                    .putBoolean("warned", false).apply()
            }
            val lastAlert = prefs.getLong("lastAlertMin", -1)
            val warned = prefs.getBoolean("warned", false)
            val over = minutes > budget
            val near = !over && budget > 0 && minutes * 10 >= budget * 8

            val speak = force ||
                (over && (lastAlert < 0 || minutes - lastAlert >= REPEAT_EVERY_MIN)) ||
                (near && !warned)
            if (!speak) return false

            val top = offenders.filter { it.second > 0 }.take(3)
                .joinToString(", ") { "${it.first} ${fmt(it.second)}" }
            val titles = cfg.optJSONArray("pendingTitles")
            val quests = (0 until (titles?.length() ?: 0)).joinToString(", ") { "\"${titles!!.getString(it)}\"" }
            val planned = cfg.optInt("plannedMin", 0).toLong()
            val done = cfg.optInt("doneMin", 0).toLong()
            val xpLoss = cfg.optInt("xpLoss", 50)

            val title = if (over) "WARNING: DEVIATION DETECTED" else "CAUTION: LIMIT APPROACHING"
            val summary = "Distraction ${fmt(minutes)} of ${fmt(budget)} allowed. $pending quest(s) pending."
            val body = buildString {
                append("Player, you have spent ${fmt(minutes)} in distractions today. ")
                append(if (over) "The limit was ${fmt(budget)}: you are ${fmt(minutes - budget)} over.\n"
                       else "The limit is ${fmt(budget)}.\n")
                if (top.isNotEmpty()) append("Offenders: $top.\n")
                append("Plan: ${fmt(done)} of ${fmt(planned)} completed, $pending quest(s) remain")
                if (quests.isNotEmpty()) append(" ($quests)")
                append(".\n")
                append(if (over) "Penalty at day end: -$xpLoss XP, and unfinished quests return as penalty quests. Return to your quest now."
                       else "Cross the limit and the penalty is -$xpLoss XP. Close the app and resume your quest.")
            }
            Alerts.alert(ctx, title, summary, body, danger = over, overlayToo = cfg.optBoolean("overlay", false))
            if (!force) {
                prefs.edit().apply {
                    if (over) putLong("lastAlertMin", minutes) else putBoolean("warned", true)
                }.apply()
            }
            return true
        }
    }
}
