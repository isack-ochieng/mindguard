package com.example.content_filter_vpn

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class LocalDecisionEngineTest {

    @Test
    fun builtInBlockedDomainIsBlocked() {
        val engine = LocalDecisionEngine()

        val decision = engine.decide("pornhub.com")

        assertEquals(DecisionAction.BLOCK, decision.action)
        assertEquals(DecisionSource.BLOCKLIST, decision.source)
        assertEquals("adult", decision.category)
    }

    @Test
    fun blockedSubdomainIsBlocked() {
        val engine = LocalDecisionEngine()

        val decision = engine.decide("www.pornhub.com")

        assertEquals(DecisionAction.BLOCK, decision.action)
        assertEquals(DecisionSource.BLOCKLIST, decision.source)
    }

    @Test
    fun similarButDifferentDomainIsNotBlockedBySubstring() {
        val engine = LocalDecisionEngine()

        val decision = engine.decide("pornhub.com.evil.example")

        assertEquals(DecisionAction.UNKNOWN, decision.action)
        assertEquals(DecisionSource.NONE, decision.source)
    }

    @Test
    fun allowlistWinsForAllowedDomain() {
        val engine = LocalDecisionEngine()

        val decision = engine.decide("mail.google.com")

        assertEquals(DecisionAction.ALLOW, decision.action)
        assertEquals(DecisionSource.ALLOWLIST, decision.source)
    }

    @Test
    fun unknownDomainDoesNotTriggerNetworkOrAiPath() {
        val engine = LocalDecisionEngine()

        val decision = engine.decide("completely-new-domain.example")

        assertEquals(DecisionAction.UNKNOWN, decision.action)
        assertEquals(DecisionSource.NONE, decision.source)
    }

    @Test
    fun customBlockedDomainAndSubdomainAreBlocked() {
        val engine = LocalDecisionEngine()
        engine.replaceUserBlockedDomains(listOf("example.net"))

        assertEquals(
            DecisionAction.BLOCK,
            engine.decide("example.net").action
        )
        assertEquals(
            DecisionAction.BLOCK,
            engine.decide("sub.example.net").action
        )
    }

    @Test
    fun replacingUserListDoesNotRemoveBuiltInPolicy() {
        val engine = LocalDecisionEngine()
        engine.replaceUserBlockedDomains(listOf("custom.example"))

        assertEquals(
            DecisionAction.BLOCK,
            engine.decide("betway.com").action
        )
        assertEquals(
            DecisionAction.BLOCK,
            engine.decide("custom.example").action
        )
    }

    @Test
    fun cacheIsUsedForPreviouslyUnknownDomain() {
        val engine = LocalDecisionEngine()

        assertEquals(
            DecisionAction.UNKNOWN,
            engine.decide("new.example").action
        )

        engine.cacheDecision(
            "new.example",
            DecisionAction.BLOCK,
            category = "phishing",
            ttlMs = 60_000
        )

        val decision = engine.decide("new.example")

        assertEquals(DecisionAction.BLOCK, decision.action)
        assertEquals(DecisionSource.CACHE, decision.source)
        assertEquals("phishing", decision.category)
        assertNotNull(decision.expiresAtEpochMs)
    }

    @Test
    fun expiredCacheFallsBackToUnknown() {
        val engine = LocalDecisionEngine()

        engine.cacheDecision(
            "temporary.example",
            DecisionAction.BLOCK,
            category = "suspicious",
            ttlMs = 1
        )

        Thread.sleep(10)

        val decision = engine.decide("temporary.example")

        assertEquals(DecisionAction.UNKNOWN, decision.action)
        assertEquals(DecisionSource.NONE, decision.source)
    }

    @Test
    fun policyListOutranksConflictingCachedAllow() {
        val engine = LocalDecisionEngine()

        engine.cacheDecision(
            "bet365.com",
            DecisionAction.ALLOW,
            category = "benign",
            ttlMs = 60_000
        )

        val decision = engine.decide("bet365.com")

        assertEquals(DecisionAction.BLOCK, decision.action)
        assertEquals(DecisionSource.BLOCKLIST, decision.source)
        assertEquals("gambling", decision.category)
    }

    @Test
    fun normalizationHandlesUrlSchemePathPortAndTrailingDot() {
        val engine = LocalDecisionEngine()

        assertEquals(
            "example.com",
            engine.normalizeDomain("  HTTPS://Example.COM:443/path?q=1.  ")
        )
    }

    @Test
    fun emptyInputIsUnknown() {
        val engine = LocalDecisionEngine()

        val decision = engine.decide("   ")

        assertEquals(DecisionAction.UNKNOWN, decision.action)
        assertEquals("", decision.domain)
    }

    @Test
    fun clearCacheRemovesMemoryDecision() {
        val engine = LocalDecisionEngine()

        engine.cacheDecision(
            "cached.example",
            DecisionAction.ALLOW,
            ttlMs = 60_000
        )

        assertEquals(
            DecisionAction.ALLOW,
            engine.decide("cached.example").action
        )

        engine.clearCache()

        val decision = engine.decide("cached.example")
        assertEquals(DecisionAction.UNKNOWN, decision.action)
        assertNull(decision.category)
    }
}
