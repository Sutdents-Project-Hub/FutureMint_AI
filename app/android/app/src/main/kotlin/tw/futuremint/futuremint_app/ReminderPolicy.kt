package tw.futuremint.futuremint_app

import java.util.GregorianCalendar
import java.util.TimeZone

internal data class ReminderOccurrence(val id: String, val at: Long)

/** Android-free validation shared by channel, alarm delivery and unit tests. */
internal object ReminderPolicy {
    const val PREFIX = "futuremint.subscription."
    const val LIMIT = 60
    private val utcDate = Regex("^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})(?:\\.(\\d{1,9}))?Z$")

    fun validOwner(owner: String?) = owner != null && owner.isNotBlank() && owner.length <= 256

    fun parseUtc(value: String): Long? {
        val parts = utcDate.matchEntire(value)?.groupValues ?: return null
        return try {
            val calendar = GregorianCalendar(TimeZone.getTimeZone("UTC"))
            calendar.isLenient = false
            calendar.clear()
            calendar.set(parts[1].toInt(), parts[2].toInt() - 1, parts[3].toInt(),
                parts[4].toInt(), parts[5].toInt(), parts[6].toInt())
            calendar.set(GregorianCalendar.MILLISECOND, parts[7].padEnd(3, '0').take(3).toInt())
            calendar.timeInMillis
        } catch (_: IllegalArgumentException) { null }
    }

    fun occurrences(values: List<*>?, now: Long): List<ReminderOccurrence> =
        (values ?: emptyList<Any>()).mapNotNull { value ->
            val item = value as? Map<*, *> ?: return@mapNotNull null
            val id = item["id"] as? String ?: return@mapNotNull null
            val at = (item["at"] as? String)?.let(::parseUtc) ?: return@mapNotNull null
            if (!id.startsWith(PREFIX) || id.length <= PREFIX.length || id.length > 512 || at <= now) null
            else ReminderOccurrence(id, at)
        }.sortedBy { it.at }.distinctBy { it.id }.take(LIMIT)

    fun shouldRequestPermission(runtimeAllowed: Boolean, requestedBefore: Boolean,
        showRationale: Boolean, dialogActive: Boolean): Boolean = !runtimeAllowed &&
        !dialogActive && (!requestedBefore || showRationale)

    fun permission(runtimeAllowed: Boolean, notificationsAllowed: Boolean,
        channelAllowed: Boolean, requestedBefore: Boolean): String = when {
        !runtimeAllowed -> if (requestedBefore) "denied" else "notDetermined"
        !notificationsAllowed || !channelAllowed -> "denied"
        else -> "authorized"
    }

    fun mayDeliver(owner: String?, token: String?, selectedOwner: String?, selectedToken: String?,
        enabled: Boolean, allowed: Boolean): Boolean = validOwner(owner) && token != null &&
        token == selectedToken && owner == selectedOwner && enabled && allowed
}

internal class ReminderBinding {
    var owner: String? = null
        private set
    var generation: Int = 0
        private set
    var bound: Boolean = false
        private set

    fun bind(nextOwner: String?, nextGeneration: Int): Boolean {
        if (nextGeneration <= generation || (nextOwner != null && !ReminderPolicy.validOwner(nextOwner))) return false
        owner = nextOwner
        generation = nextGeneration
        bound = true
        return true
    }

    fun matches(account: String?, expected: Int): Boolean = bound &&
        ReminderPolicy.validOwner(account) && account == owner && expected == generation
}
