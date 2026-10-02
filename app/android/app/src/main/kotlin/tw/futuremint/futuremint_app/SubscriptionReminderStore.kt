package tw.futuremint.futuremint_app

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Private local metadata only: account identifier, occurrence identifier/time and opt-in. */
internal class SubscriptionReminderStore(private val context: Context) {
    companion object {
        const val CHANNEL = "futuremint.subscription-reminders"
        const val OPEN_ACTION = "tw.futuremint.SUBSCRIPTION_REMINDER_OPEN"
        const val OWNER = "futuremintOwner"
        const val TOKEN = "futuremintReminderToken"
        const val ID = "futuremintReminderId"
        private const val PREFS = "futuremint.subscription-reminders"
    }
    private val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val owner: String? get() = preferences.getString("selectedOwner", null)
    val token: String? get() = preferences.getString("selectedToken", null)
    var requestedBefore: Boolean
        get() = preferences.getBoolean("permissionRequested", false)
        set(value) { check(preferences.edit().putBoolean("permissionRequested", value).commit()) }

    fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            notifications.createNotificationChannel(NotificationChannel(CHANNEL, "訂閱續訂提醒", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "續訂前檢查使用情況的本機提醒"
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
        }
    }

    fun runtimeAllowed(): Boolean = Build.VERSION.SDK_INT < 33 ||
        context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun channelAllowed(): Boolean = Build.VERSION.SDK_INT < 26 ||
        notifications.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE

    fun permission(): String = ReminderPolicy.permission(runtimeAllowed(),
        notifications.areNotificationsEnabled(), channelAllowed(), requestedBefore)

    fun enabled(account: String): Boolean = preferences.getBoolean("enabled.$account", false)
    fun setEnabled(account: String, value: Boolean) {
        check(preferences.edit().putBoolean("enabled.$account", value).commit())
        if (!value) clear()
    }

    fun state(account: String?): Map<String, Any> {
        val permission = permission()
        return mapOf("enabled" to (account != null && enabled(account) && permission == "authorized"),
            "permission" to permission)
    }

    fun bind(account: String?) {
        clear()
        check(preferences.edit().putString("selectedOwner", account)
            .putString("selectedToken", account?.let { UUID.randomUUID().toString() }).commit())
    }

    private fun occurrences(): List<ReminderOccurrence> = try {
        val values = JSONArray(preferences.getString("occurrences", "[]"))
        (0 until values.length()).mapNotNull { index ->
            val value = values.optJSONObject(index) ?: return@mapNotNull null
            val id = value.optString("id")
            val at = value.optLong("at", -1)
            if (id.startsWith(ReminderPolicy.PREFIX) && at > 0) ReminderOccurrence(id, at) else null
        }.take(ReminderPolicy.LIMIT)
    } catch (_: Exception) { emptyList() }

    private fun save(values: List<ReminderOccurrence>) {
        val array = JSONArray()
        values.forEach { array.put(JSONObject().put("id", it.id).put("at", it.at)) }
        check(preferences.edit().putString("occurrences", array.toString()).commit())
    }

    private fun alarmIntent(item: ReminderOccurrence, account: String?, bindingToken: String?): Intent =
        Intent(context, SubscriptionReminderReceiver::class.java).apply {
            data = Uri.Builder().scheme("futuremint-reminder").authority("alarm")
                .appendPath(bindingToken ?: "").appendPath(item.id).build()
            putExtra(OWNER, account)
            putExtra(TOKEN, bindingToken)
            putExtra(ID, item.id)
        }

    private fun schedule(values: List<ReminderOccurrence>, account: String, bindingToken: String) {
        values.forEach { item ->
            val pending = PendingIntent.getBroadcast(context, 0, alarmIntent(item, account, bindingToken),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            // Inexact: avoids exact-alarm access and does not request battery exemptions.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, item.at, pending)
        }
    }

    fun clear() {
        val previous = occurrences()
        val account = owner
        val bindingToken = token
        // Invalidate before cancelling: any already queued broadcast fails closed.
        save(emptyList())
        previous.forEach { item ->
            PendingIntent.getBroadcast(context, 0, alarmIntent(item, account, bindingToken),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)?.let {
                alarms.cancel(it)
                it.cancel()
            }
        }
        notifications.activeNotifications.filter { it.tag?.startsWith(ReminderPolicy.PREFIX) == true }
            .forEach { notifications.cancel(it.tag, it.id) }
    }

    fun replace(values: List<*>) {
        clear()
        val account = owner ?: return
        val bindingToken = token ?: return
        if (!enabled(account) || permission() != "authorized") return
        val selected = ReminderPolicy.occurrences(values, System.currentTimeMillis())
        save(selected)
        try { schedule(selected, account, bindingToken) }
        catch (error: Exception) { clear(); throw error }
    }

    fun restore() {
        createChannel()
        val account = owner ?: return
        val bindingToken = token ?: return
        if (!enabled(account) || permission() != "authorized") { clear(); return }
        val future = occurrences().filter { it.at > System.currentTimeMillis() }
        save(future)
        try { schedule(future, account, bindingToken) }
        catch (_: Exception) { clear() }
    }

    fun validTap(intent: Intent?): String? {
        if (intent?.action != OPEN_ACTION) return null
        val account = intent.getStringExtra(OWNER)
        return account?.takeIf { ReminderPolicy.mayDeliver(it, intent.getStringExtra(TOKEN), owner, token,
            enabled(it), permission() == "authorized") }
    }

    fun deliver(intent: Intent) {
        createChannel()
        val account = intent.getStringExtra(OWNER)
        val bindingToken = intent.getStringExtra(TOKEN)
        if (!ReminderPolicy.mayDeliver(account, bindingToken, owner, token,
                account?.let(::enabled) == true, permission() == "authorized")) return
        val item = occurrences().firstOrNull { it.id == intent.getStringExtra(ID) } ?: return
        if (item.at > System.currentTimeMillis()) return
        // Consume before posting so duplicate broadcasts never redeliver.
        save(occurrences().filter { it.id != item.id })
        val open = Intent(context, MainActivity::class.java).apply {
            action = OPEN_ACTION
            data = Uri.Builder().scheme("futuremint-reminder").authority("open")
                .appendPath(bindingToken).appendPath(item.id).build()
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(OWNER, account)
            putExtra(TOKEN, bindingToken)
        }
        val pending = PendingIntent.getActivity(context, 0, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
            else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.subscription_notification)
            .setContentTitle("訂閱續訂提醒")
            .setContentText("續訂前先看看最近的使用情況，再決定下一步。")
            .setContentIntent(pending).setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setCategory(Notification.CATEGORY_REMINDER).build()
        try { notifications.notify(item.id, 0, notification) }
        catch (_: SecurityException) { /* Permission may be revoked between check and post. */ }
    }
}

class SubscriptionReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SubscriptionReminderStore(context).deliver(intent)
    }
}

class SubscriptionReminderRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            SubscriptionReminderStore(context).restore()
        }
    }
}
