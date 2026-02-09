package com.example.content_filter_vpn

import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

class DnsResolver(private val blockedDomains: Set<String>) {
    
    private val dnsCache = ConcurrentHashMap<String, String>()
    private val blockedIpCache = ConcurrentHashMap<String, Boolean>()
    
    fun isDomainBlocked(domain: String): Boolean {
        val normalizedDomain = domain.lowercase().trim()
        
        // Check exact match
        if (blockedDomains.contains(normalizedDomain)) {
            return true
        }
        
        // Check if any blocked domain is a suffix of the queried domain
        for (blockedDomain in blockedDomains) {
            if (normalizedDomain.endsWith(".$blockedDomain") || 
                normalizedDomain == blockedDomain) {
                return true
            }
        }
        
        return false
    }
    
    fun isIpBlocked(ip: String): Boolean {
        // Check cache first
        blockedIpCache[ip]?.let { return it }
        
        // In a real implementation, you would do reverse DNS lookup
        // For now, we'll just cache the result
        val blocked = false
        blockedIpCache[ip] = blocked
        return blocked
    }
    
    fun resolveDomain(domain: String): String? {
        // Check cache
        dnsCache[domain]?.let { return it }
        
        try {
            val address = InetAddress.getByName(domain)
            val ip = address.hostAddress
            if (ip != null) {
                dnsCache[domain] = ip
                return ip
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return null
    }
    
    fun clearCache() {
        dnsCache.clear()
        blockedIpCache.clear()
    }
}
