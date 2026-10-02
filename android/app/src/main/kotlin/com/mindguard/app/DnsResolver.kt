package com.mindguard.app

import android.content.Context

/**
 * Small local policy facade. It does not perform network requests.
 */
class DnsResolver(
    context: Context,
    blockedDomains: Set<String> = emptySet()
) {
    private val decisionEngine = LocalDecisionEngine(
        cachePreferences = context.getSharedPreferences(
            "mindguard_local_intelligence",
            Context.MODE_PRIVATE
        )
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
}
