package com.example.content_filter_vpn

import android.content.SharedPreferences
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

enum class DecisionAction {
    ALLOW,
    BLOCK,
    UNKNOWN
}

enum class DecisionSource {
    ALLOWLIST,
    BLOCKLIST,
    CACHE,
    REPUTATION,
    NONE
}

data class DomainDecision(
    val domain: String,
    val action: DecisionAction,
    val source: DecisionSource,
    val category: String? = null,
    val expiresAtEpochMs: Long? = null
)

/**
 * Fast, local domain decision engine.
 *
 * Order is intentional:
 *   1. Explicit local allowlist
 *   2. Explicit local blocklist
 *   3. Cached previous decisions
 *   4. Local reputation
 *   5. UNKNOWN (future AI/network intelligence layer)
 *
 * No network request and no AI call happens in this class.
 */
class LocalDecisionEngine(
    private val cachePreferences: SharedPreferences? = null,
    private val cacheTtlMs: Long = DEFAULT_CACHE_TTL_MS
) {
    companion object {
        private const val CACHE_PREFIX = "mindguard.decision."
        private const val CATEGORY_SUFFIX = ".category"
        private const val ACTION_SUFFIX = ".action"
        private const val EXPIRY_SUFFIX = ".expiry"
        private const val DEFAULT_CACHE_TTL_MS = 24L * 60L * 60L * 1000L
    }

    private val blockedDomains = ConcurrentHashMap<String, String>()
    private val allowedDomains = ConcurrentHashMap.newKeySet<String>()
    private val reputation = ConcurrentHashMap<String, String>()
    private val memoryCache = ConcurrentHashMap<String, CachedDecision>()

    init {
        PolicyLists.blockedDomains.forEach { (domain, category) ->
            blockedDomains[normalizeDomain(domain)] = category
        }
        PolicyLists.allowedDomains.forEach { domain ->
            allowedDomains.add(normalizeDomain(domain))
        }
        PolicyLists.riskyReputation.forEach { (domain, category) ->
            reputation[normalizeDomain(domain)] = category
        }
    }

    @Synchronized
    fun replaceUserBlockedDomains(domains: Collection<String>) {
        val builtIn = PolicyLists.blockedDomains
            .mapKeys { normalizeDomain(it.key) }

        blockedDomains.clear()
        blockedDomains.putAll(builtIn)

        domains.forEach { raw ->
            val domain = normalizeDomain(raw)
            if (domain.isNotEmpty()) {
                blockedDomains[domain] = "custom"
            }
        }
    }

    fun decide(rawDomain: String): DomainDecision {
        val domain = normalizeDomain(rawDomain)
        if (domain.isEmpty()) {
            return DomainDecision("", DecisionAction.UNKNOWN, DecisionSource.NONE)
        }

        // Policy lists always outrank cached decisions.
        if (matchesDomain(domain, allowedDomains)) {
            return DomainDecision(
                domain = domain,
                action = DecisionAction.ALLOW,
                source = DecisionSource.ALLOWLIST
            )
        }

        val blockedCategory = matchingCategory(domain, blockedDomains)
        if (blockedCategory != null) {
            return DomainDecision(
                domain = domain,
                action = DecisionAction.BLOCK,
                source = DecisionSource.BLOCKLIST,
                category = blockedCategory
            )
        }

        val cached = readCached(domain)
        if (cached != null) {
            return cached
        }

        val reputationCategory = matchingCategory(domain, reputation)
        if (reputationCategory != null) {
            val decision = DomainDecision(
                domain = domain,
                action = DecisionAction.BLOCK,
                source = DecisionSource.REPUTATION,
                category = reputationCategory
            )
            cache(domain, decision)
            return decision
        }

        return DomainDecision(
            domain = domain,
            action = DecisionAction.UNKNOWN,
            source = DecisionSource.NONE
        )
    }

    fun cacheDecision(
        rawDomain: String,
        action: DecisionAction,
        category: String? = null,
        ttlMs: Long = cacheTtlMs
    ) {
        val domain = normalizeDomain(rawDomain)
        if (domain.isEmpty() || action == DecisionAction.UNKNOWN) return

        val decision = DomainDecision(
            domain = domain,
            action = action,
            source = DecisionSource.CACHE,
            category = category,
            expiresAtEpochMs = System.currentTimeMillis() + ttlMs
        )
        cache(domain, decision)
    }

    fun clearCache() {
        memoryCache.clear()
        val prefs = cachePreferences ?: return
        val editor = prefs.edit()
        prefs.all.keys
            .filter { it.startsWith(CACHE_PREFIX) }
            .forEach { editor.remove(it) }
        editor.apply()
    }

    fun normalizeDomain(rawDomain: String): String {
        var domain = rawDomain.trim().lowercase(Locale.US)

        // Accept host-like input without treating arbitrary URL text as a domain.
        domain = domain.removePrefix("https://").removePrefix("http://")
        domain = domain.substringBefore('/')
        domain = domain.substringBefore('?')
        domain = domain.substringBefore('#')
        domain = domain.substringBefore(':')
        domain = domain.trimEnd('.')

        return domain
    }

    private fun matchesDomain(domain: String, rules: Collection<String>): Boolean {
        return rules.any { rule ->
            domain == rule || domain.endsWith(".$rule")
        }
    }

    private fun matchingCategory(
        domain: String,
        rules: Map<String, String>
    ): String? {
        rules[domain]?.let { return it }

        var bestMatch: String? = null
        var bestLength = -1

        for ((rule, category) in rules) {
            if (domain.endsWith(".$rule") && rule.length > bestLength) {
                bestMatch = category
                bestLength = rule.length
            }
        }

        return bestMatch
    }

    private fun cache(domain: String, decision: DomainDecision) {
        val expires = decision.expiresAtEpochMs ?: return
        memoryCache[domain] = CachedDecision(decision, expires)

        cachePreferences?.edit()
            ?.putString(CACHE_PREFIX + domain + ACTION_SUFFIX, decision.action.name)
            ?.putString(CACHE_PREFIX + domain + CATEGORY_SUFFIX, decision.category)
            ?.putLong(CACHE_PREFIX + domain + EXPIRY_SUFFIX, expires)
            ?.apply()
    }

    private fun readCached(domain: String): DomainDecision? {
        val now = System.currentTimeMillis()

        memoryCache[domain]?.let { cached ->
            if (cached.expiresAtEpochMs > now) return cached.decision
            memoryCache.remove(domain)
        }

        val prefs = cachePreferences ?: return null
        val prefix = CACHE_PREFIX + domain
        val expiry = prefs.getLong(prefix + EXPIRY_SUFFIX, 0L)

        if (expiry <= now) {
            if (expiry != 0L) prefs.edit()
                .remove(prefix + ACTION_SUFFIX)
                .remove(prefix + CATEGORY_SUFFIX)
                .remove(prefix + EXPIRY_SUFFIX)
                .apply()
            return null
        }

        val actionName = prefs.getString(prefix + ACTION_SUFFIX, null) ?: return null
        val action = runCatching { DecisionAction.valueOf(actionName) }.getOrNull()
            ?: return null

        if (action == DecisionAction.UNKNOWN) return null

        val decision = DomainDecision(
            domain = domain,
            action = action,
            source = DecisionSource.CACHE,
            category = prefs.getString(prefix + CATEGORY_SUFFIX, null),
            expiresAtEpochMs = expiry
        )

        memoryCache[domain] = CachedDecision(decision, expiry)
        return decision
    }

    private data class CachedDecision(
        val decision: DomainDecision,
        val expiresAtEpochMs: Long
    )
}
