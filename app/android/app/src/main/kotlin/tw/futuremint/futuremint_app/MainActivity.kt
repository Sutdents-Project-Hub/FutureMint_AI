package tw.futuremint.futuremint_app

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val store by lazy { SubscriptionReminderStore(this) }
    private val binding = ReminderBinding()
    private var reminders: MethodChannel? = null
    private var pendingOpenOwner: String? = null
    private data class PermissionRequest(val account: String, val generation: Int, val result: MethodChannel.Result)
    private var permissionRequest: PermissionRequest? = null
    private var permissionDialogActive = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // Capture a cold-launch tap before bind replaces the persisted alarm token.
        pendingOpenOwner = store.validTap(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        store.createChannel()
        reminders = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "futuremint/subscription-reminders").also {
            it.setMethodCallHandler(::handleReminder)
        }
    }

    private fun cancelPendingPermission() {
        permissionRequest?.result?.success(null)
        permissionRequest = null
    }

    private fun handleReminder(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val account = args["owner"] as? String
        val requestedGeneration = args["generation"]
        val expected = when (requestedGeneration) {
            is Int -> requestedGeneration
            is Long -> if (requestedGeneration in 1..Int.MAX_VALUE.toLong()) requestedGeneration.toInt() else -1
            else -> -1
        }
        try {
            if (call.method == "bind") {
                if ((args["owner"] != null && account == null) || !binding.bind(account, expected)) {
                    result.success(null); return
                }
                cancelPendingPermission()
                store.bind(account)
                result.success(store.state(account))
                val tapped = pendingOpenOwner
                pendingOpenOwner = null
                if (tapped != null && tapped == account) reminders?.invokeMethod("open", tapped)
                return
            }
            if (!binding.matches(account, expected)) { result.success(null); return }
            // matches guarantees a non-null, valid owner.
            val selected = account!!
            when (call.method) {
                "status" -> {
                    if (store.permission() != "authorized") store.clear()
                    result.success(store.state(selected))
                }
                "setEnabled" -> {
                    val value = args["enabled"] as? Boolean
                    if (value == null) { result.success(null); return }
                    cancelPendingPermission()
                    if (!value) {
                        store.setEnabled(selected, false)
                        result.success(store.state(selected))
                    } else if (Build.VERSION.SDK_INT >= 33 && ReminderPolicy.shouldRequestPermission(
                        store.runtimeAllowed(), store.requestedBefore,
                        shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS), permissionDialogActive)) {
                        // Explicit toggle only. Neither bind/status nor boot can request permission.
                        store.setEnabled(selected, false)
                        permissionRequest = PermissionRequest(selected, expected, result)
                        permissionDialogActive = true
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_REQUEST)
                    } else {
                        store.setEnabled(selected, store.permission() == "authorized")
                        result.success(store.state(selected))
                    }
                }
                "replace" -> {
                    store.replace(args["occurrences"] as? List<*> ?: emptyList<Any>())
                    result.success(null)
                }
                "openSettings" -> result.success(openNotificationSettings())
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            if (permissionRequest?.result === result) {
                permissionRequest = null
                permissionDialogActive = false
            }
            result.error("reminder_failed", "無法更新本機提醒，請稍後重試。", null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_REQUEST) return
        permissionDialogActive = false
        val pending = permissionRequest
        permissionRequest = null
        // Empty results mean dismissal/interruption; retain the ability to ask on the next explicit toggle.
        if (grantResults.isNotEmpty()) store.requestedBefore = true
        if (pending == null) return
        if (!binding.matches(pending.account, pending.generation)) { pending.result.success(null); return }
        try {
            store.setEnabled(pending.account, store.permission() == "authorized")
            pending.result.success(store.state(pending.account))
        } catch (_: Exception) {
            pending.result.error("reminder_failed", "無法更新本機提醒，請稍後重試。", null)
        }
    }

    private fun openNotificationSettings(): Boolean {
        val notificationSettings = Intent(if (Build.VERSION.SDK_INT >= 26 && !store.channelAllowed())
            Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS else Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            if (Build.VERSION.SDK_INT >= 26) putExtra(Settings.EXTRA_CHANNEL_ID, SubscriptionReminderStore.CHANNEL)
        }
        for (target in listOf(notificationSettings,
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))) {
            try { startActivity(target); return true }
            catch (_: ActivityNotFoundException) { /* Try standard app-details settings. */ }
            catch (_: SecurityException) { /* Some managed devices restrict settings. */ }
        }
        return false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val tapped = store.validTap(intent) ?: return
        if (binding.bound) {
            if (tapped == binding.owner) reminders?.invokeMethod("open", tapped)
        } else { pendingOpenOwner = tapped }
    }

    override fun onDestroy() {
        cancelPendingPermission()
        reminders?.setMethodCallHandler(null)
        reminders = null
        pendingOpenOwner = null
        super.onDestroy()
    }

    companion object { private const val NOTIFICATION_REQUEST = 7401 }
}
