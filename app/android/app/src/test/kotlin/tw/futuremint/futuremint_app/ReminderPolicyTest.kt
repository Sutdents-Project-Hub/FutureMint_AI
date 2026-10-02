package tw.futuremint.futuremint_app

import org.junit.Assert.*
import org.junit.Test
import java.util.TimeZone

class ReminderPolicyTest {
    @Test fun utcScheduleIgnoresDeviceTimezoneAndAcceptsDartFractions() {
        val previous = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/Los_Angeles"))
            assertEquals(1790902800123L, ReminderPolicy.parseUtc("2026-10-02T01:00:00.123456Z"))
            assertEquals(ReminderPolicy.parseUtc("2026-10-02T01:00:00.000Z"),
                ReminderPolicy.parseUtc("2026-10-02T01:00:00Z"))
        } finally { TimeZone.setDefault(previous) }
    }

    @Test fun invalidAndPastOccurrencesCannotBecomeAlarms() {
        val now = ReminderPolicy.parseUtc("2026-10-02T01:00:00Z")!!
        assertNull(ReminderPolicy.parseUtc("2026-02-30T01:00:00Z"))
        assertNull(ReminderPolicy.parseUtc("2026-10-02T25:00:00Z"))
        assertNull(ReminderPolicy.parseUtc("2026-10-02T01:00:00+08:00"))
        assertTrue(ReminderPolicy.occurrences(listOf(
            mapOf("id" to "other", "at" to "2026-12-02T01:00:00Z"),
            mapOf("id" to "futuremint.subscription.past", "at" to "2026-10-02T01:00:00Z"),
            mapOf("id" to "futuremint.subscription.bad", "at" to "bad"), null), now).isEmpty())
    }

    @Test fun selectsEarliestSixtyAndDeduplicatesIdentifiers() {
        val values = (1..70).reversed().map {
            mapOf("id" to "futuremint.subscription.$it", "at" to "2027-01-01T01:00:${(it % 60).toString().padStart(2, '0')}.${it.toString().padStart(3, '0')}Z")
        }
        val selected = ReminderPolicy.occurrences(values + values.first(), 0)
        assertEquals(60, selected.size)
        assertEquals(60, selected.map { it.id }.toSet().size)
        assertTrue(selected.zipWithNext().all { (a, b) -> a.at <= b.at })
        assertEquals(ReminderPolicy.occurrences(values, 0), selected)
    }

    @Test fun generationAndOwnerPreventOldMutationsAndPermissionResults() {
        val binding = ReminderBinding()
        assertFalse(binding.matches("a", 0))
        assertTrue(binding.bind("a", 1))
        assertTrue(binding.matches("a", 1))
        assertTrue(binding.bind("b", 2))
        assertFalse(binding.matches("a", 1))
        assertFalse(binding.matches("a", 2))
        assertFalse(binding.matches("b", 1))
        assertFalse(binding.bind("a", 1))
        assertFalse(binding.bind("a", 2))
        assertTrue(binding.bind(null, 3))
        assertFalse(binding.matches("b", 2))
        assertFalse(binding.matches(null, 3))
        assertFalse(binding.bind(" ", 4))
        assertNull(binding.owner)
    }

    @Test fun runtimeAppAndChannelPermissionsAllGateEffectivePermission() {
        assertEquals("notDetermined", ReminderPolicy.permission(false, false, true, false))
        assertEquals("denied", ReminderPolicy.permission(false, false, true, true))
        assertEquals("denied", ReminderPolicy.permission(true, false, true, true))
        assertEquals("denied", ReminderPolicy.permission(true, true, false, false))
        assertEquals("authorized", ReminderPolicy.permission(true, true, true, false))
    }

    @Test fun requestsOnlyOnFirstAttemptOrRetryAndNotAfterPermanentDenial() {
        assertTrue(ReminderPolicy.shouldRequestPermission(false, false, false, false))
        assertTrue(ReminderPolicy.shouldRequestPermission(false, true, true, false))
        assertFalse(ReminderPolicy.shouldRequestPermission(false, true, false, false))
        assertFalse(ReminderPolicy.shouldRequestPermission(false, false, false, true))
        assertFalse(ReminderPolicy.shouldRequestPermission(true, true, true, false))
    }

    @Test fun duplicateIdentifierKeepsEarliestValidTime() {
        val values = listOf(
            mapOf("id" to "futuremint.subscription.same", "at" to "2027-12-01T01:00:00Z"),
            mapOf("id" to "futuremint.subscription.same", "at" to "2027-01-01T01:00:00Z"))
        assertEquals(listOf(ReminderOccurrence("futuremint.subscription.same",
            ReminderPolicy.parseUtc("2027-01-01T01:00:00Z")!!)), ReminderPolicy.occurrences(values, 0))
    }

    @Test fun oldAccountOrOldBindingOrRevokedPermissionCannotDeliverOrOpen() {
        assertTrue(ReminderPolicy.mayDeliver("a", "token1", "a", "token1", true, true))
        assertFalse(ReminderPolicy.mayDeliver("a", "token1", "b", "token2", true, true))
        assertFalse(ReminderPolicy.mayDeliver("a", "token1", "a", "token2", true, true))
        assertFalse(ReminderPolicy.mayDeliver("a", "token1", "a", "token1", false, true))
        assertFalse(ReminderPolicy.mayDeliver("a", "token1", "a", "token1", true, false))
        assertFalse(ReminderPolicy.mayDeliver(null, null, null, null, true, true))
    }
}
