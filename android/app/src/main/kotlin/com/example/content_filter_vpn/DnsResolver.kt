package com.example.content_filter_vpn

import android.content.Context
import android.net.Network
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

/**
 * DNS/domain helper backed by MindGuard's local decision engine.
 *
 * Unknown domains remain unknown here. Intelligence can be layered on later
 * without putting a network call in the packet hot path.
 */
class DnsResolver(
    context: Context,
    private var underlyingNetwork: Network? = null,
    blockedDomains: Set<String> = emptySet()
) {
    companion object {
        private const val LEARNED_IP_TTL_MS = 10L * 60L * 1000L
    }

    private val dnsCache = ConcurrentHashMap<String, String>()
    private val blockedIpCache = ConcurrentHashMap<String, Long>()
    private val decisionEngine = LocalDecisionEngine(
        cachePreferences = context.getSharedPreferences(
            "mindguard_local_intelligence",
            Context.MODE_PRIVATE
        )
    )

    init {
        updateBlockedDomains(blockedDomains)
    }

    fun updateUnderlyingNetwork(network: Network?) {
        underlyingNetwork = network
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

    /**
     * Called when MindGuard observes a DNS question. For domains already known
     * to be blocked, resolve their current addresses on the underlying network
     * and keep a short-lived IP correlation so ECH/direct-IP connections can
     * still be rejected.
     */
    fun observeDomain(domain: String) {
        val decision = decisionEngine.decide(domain)
        if (decision.action != DecisionAction.BLOCK) return

        val normalized = decision.domain

        runCatching {
            resolveAllOnUnderlyingNetwork(normalized).forEach { address ->
                address.hostAddress?.let { ip ->
                    blockedIpCache[ip] = System.currentTimeMillis() + LEARNED_IP_TTL_MS
                }
            }
        }
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
        val expiry = blockedIpCache[ip] ?: return false
        if (expiry > System.currentTimeMillis()) return true

        blockedIpCache.remove(ip, expiry)
        return false
    }

    fun resolveDomain(domain: String): String? {
        val normalized = decisionEngine.normalizeDomain(domain)
        dnsCache[normalized]?.let { return it }

        return try {
            val address = resolveAllOnUnderlyingNetwork(normalized).firstOrNull()
                ?: return null
            val ip = address.hostAddress
            if (ip != null) {
                dnsCache[normalized] = ip
            }
            ip
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveAllOnUnderlyingNetwork(domain: String): Array<InetAddress> {
        return runCatching {
            underlyingNetwork?.getAllByName(domain)
                ?: InetAddress.getAllByName(domain)
        }.getOrDefault(emptyArray())
    }

    fun clearCache() {
        dnsCache.clear()
        blockedIpCache.clear()
        decisionEngine.clearCache()
    }
}
