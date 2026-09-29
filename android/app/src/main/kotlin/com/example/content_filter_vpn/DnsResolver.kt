package com.example.content_filter_vpn

import android.content.Context
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

/**
 * DNS/domain helper backed by MindGuard's local decision engine.
 *
 * It intentionally does not perform remote classification. Unknown domains are
 * returned as unknown so a later intelligence layer can handle them.
 */
class DnsResolver(
    context: Context,
    blockedDomains: Set<String> = emptySet()
) {
    private val dnsCache = ConcurrentHashMap<String, String>()
    private val blockedIpCache = ConcurrentHashMap<String, Boolean>()
    private val decisionEngine = LocalDecisionEngine(
        cachePreferences = context.getSharedPreferences("mindguard_local_intelligence", Context.MODE_PRIVATE)
    )

    init {
        updateBlockedDomains(blockedDomains)
    }

    fun updateBlockedDomains(domains: Collection<String>) {
        decisionEngine.replaceUserBlockedDomains(domains)
    }

    fun isDomainBlocked(domain: String): Boolean {
        return decisionEngine.decide(domain).action == DecisionAction.BLOCK
    }

    fun decideDomain(domain: String): DomainDecision {
        return decisionEngine.decide(domain)
    }

    fun cacheDecision(
        domain: String,
        action: DecisionAction,
        category: String? = null,
        ttlMs: Long = 24L * 60L * 60L * 1000L
    ) {
        decisionEngine.cacheDecision(domain, action, category, ttlMs)
    }

    fun isIpBlocked(ip: String): Boolean {
        return blockedIpCache[ip] ?: false
    }

    fun resolveDomain(domain: String): String? {
        val normalized = decisionEngine.normalizeDomain(domain)
        dnsCache[normalized]?.let { return it }

        return try {
            val address = InetAddress.getByName(normalized)
            val ip = address.hostAddress
            if (ip != null) {
                dnsCache[normalized] = ip
            }
            ip
        } catch (_: Exception) {
            null
        }
    }

    fun clearCache() {
        dnsCache.clear()
        blockedIpCache.clear()
        decisionEngine.clearCache()
    }
}
