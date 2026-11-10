package dev.gaurav.arise

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var launchAlert: String? = null
    private var notifResult: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchAlert = intent?.getStringExtra(Alerts.EXTRA_ALERT)
        Alerts.ensureChannels(this)
        WatchWorker.schedule(applicationContext)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = intent.getStringExtra(Alerts.EXTRA_ALERT) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("alert", text) else launchAlert = text
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "arise/system")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(Usage.hasAccess(this))
                "openUsageAccess" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "usage" -> {
                    val start = (call.argument<Number>("start") ?: 0).toLong()
                    val end = (call.argument<Number>("end") ?: 0).toLong()
                    // Event scans can take a moment: keep them off the UI thread.
                    io.execute {
                        val out = ArrayList<Map<String, Any>>()
                        try {
                            if (Usage.hasAccess(this)) {
                                for ((pkg, ms) in Usage.foregroundMs(this, start, end)) {
                                    if (ms < 30_000) continue
                                    val (label, category) = Usage.describe(packageManager, pkg)
                                    out.add(mapOf("pkg" to pkg, "label" to label, "ms" to ms, "cat" to category))
                                }
                            }
                        } catch (_: Exception) {
                        }
                        runOnUiThread { result.success(out) }
                    }
                }
                "saveWatchConfig" -> {
                    WatchWorker.saveConfig(applicationContext, call.arguments as Map<*, *>)
                    result.success(null)
                }
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT < 33 ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else {
                        notifResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
                    }
                }
                "notificationsAllowed" -> result.success(
                    getSystemService(NotificationManager::class.java).areNotificationsEnabled()
                )
                "canOverlay" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                    )
                    result.success(null)
                }
                "ignoresBattery" -> result.success(
                    getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)
                )
                "requestIgnoreBattery" -> {
                    try {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                        )
                    } catch (_: Exception) {
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    }
                    result.success(null)
                }
                "testAlert" -> {
                    io.execute {
                        val spoke = try {
                            WatchWorker.check(applicationContext, force = true)
                        } catch (_: Exception) {
                            false
                        }
                        runOnUiThread { result.success(spoke) }
                    }
                }
                "focusNotification" -> {
                    Alerts.focus(
                        this, call.argument<String>("title"),
                        (call.argument<Number>("started") ?: 0).toLong()
                    )
                    result.success(null)
                }
                "consumeLaunchAlert" -> {
                    result.success(launchAlert)
                    launchAlert = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7) {
            notifResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            notifResult = null
        }
    }
}
