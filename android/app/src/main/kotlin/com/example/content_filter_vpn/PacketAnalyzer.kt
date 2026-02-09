package com.example.content_filter_vpn

import java.nio.ByteBuffer

class PacketAnalyzer(private val dnsResolver: DnsResolver) {
    
    companion object {
        private const val IP_HEADER_MIN_LENGTH = 20
        private const val TCP_PROTOCOL = 6
        private const val UDP_PROTOCOL = 17
        private const val DNS_PORT = 53
        private const val HTTP_PORT = 80
        private const val HTTPS_PORT = 443
    }
    
    data class PacketInfo(
        val protocol: Int,
        val sourceIp: String,
        val destIp: String,
        val sourcePort: Int,
        val destPort: Int,
        val domain: String? = null,
        val shouldBlock: Boolean = false
    )
    
    fun analyzePacket(buffer: ByteBuffer): PacketInfo? {
        try {
            if (buffer.remaining() < IP_HEADER_MIN_LENGTH) {
                return null
            }
            
            val version = (buffer.get(0).toInt() shr 4) and 0x0F
            
            if (version != 4) {
                // Only support IPv4 for now
                return null
            }
            
            val protocol = buffer.get(9).toInt() and 0xFF
            
            // Extract source and destination IP
            val sourceIp = extractIpAddress(buffer, 12)
            val destIp = extractIpAddress(buffer, 16)
            
            // Get IP header length
            val ihl = (buffer.get(0).toInt() and 0x0F) * 4
            
            var sourcePort = 0
            var destPort = 0
            var domain: String? = null
            
            // Extract port information for TCP/UDP
            if (protocol == TCP_PROTOCOL || protocol == UDP_PROTOCOL) {
                if (buffer.remaining() >= ihl + 4) {
                    sourcePort = ((buffer.get(ihl).toInt() and 0xFF) shl 8) or 
                                 (buffer.get(ihl + 1).toInt() and 0xFF)
                    destPort = ((buffer.get(ihl + 2).toInt() and 0xFF) shl 8) or 
                               (buffer.get(ihl + 3).toInt() and 0xFF)
                }
                
                // Check if this is a DNS query
                if (destPort == DNS_PORT && protocol == UDP_PROTOCOL) {
                    domain = extractDnsQuery(buffer, ihl + 8)
                }
                
                // Check if this is HTTP/HTTPS traffic
                if (destPort == HTTP_PORT || destPort == HTTPS_PORT) {
                    domain = extractHttpHost(buffer, ihl)
                }
            }
            
            // Check if destination should be blocked
            val shouldBlock = when {
                domain != null -> dnsResolver.isDomainBlocked(domain)
                else -> dnsResolver.isIpBlocked(destIp)
            }
            
            return PacketInfo(
                protocol = protocol,
                sourceIp = sourceIp,
                destIp = destIp,
                sourcePort = sourcePort,
                destPort = destPort,
                domain = domain,
                shouldBlock = shouldBlock
            )
            
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
    
    private fun extractIpAddress(buffer: ByteBuffer, offset: Int): String {
        return buildString {
            for (i in 0 until 4) {
                if (i > 0) append('.')
                append(buffer.get(offset + i).toInt() and 0xFF)
            }
        }
    }
    
    private fun extractDnsQuery(buffer: ByteBuffer, offset: Int): String? {
        try {
            if (buffer.remaining() < offset + 12) {
                return null
            }
            
            // Skip DNS header (12 bytes)
            var pos = offset + 12
            val domain = StringBuilder()
            
            while (pos < buffer.limit()) {
                val length = buffer.get(pos).toInt() and 0xFF
                if (length == 0) break
                
                pos++
                if (domain.isNotEmpty()) domain.append('.')
                
                for (i in 0 until length) {
                    if (pos >= buffer.limit()) break
                    domain.append(buffer.get(pos++).toInt().toChar())
                }
            }
            
            return if (domain.isNotEmpty()) domain.toString() else null
            
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
    
    private fun extractHttpHost(buffer: ByteBuffer, ipHeaderLength: Int): String? {
        try {
            // This is a simplified implementation
            // In reality, you'd need to parse HTTP headers properly
            val tcpHeaderLength = ((buffer.get(ipHeaderLength + 12).toInt() shr 4) and 0x0F) * 4
            val dataOffset = ipHeaderLength + tcpHeaderLength
            
            if (buffer.remaining() < dataOffset + 20) {
                return null
            }
            
            // Look for "Host: " header in HTTP request
            val httpData = ByteArray(Math.min(500, buffer.remaining() - dataOffset))
            buffer.position(dataOffset)
            buffer.get(httpData)
            
            val httpString = String(httpData, Charsets.US_ASCII)
            val hostIndex = httpString.indexOf("Host: ", ignoreCase = true)
            
            if (hostIndex != -1) {
                val hostStart = hostIndex + 6
                val hostEnd = httpString.indexOf("\r\n", hostStart)
                if (hostEnd != -1) {
                    return httpString.substring(hostStart, hostEnd).trim()
                }
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return null
    }
}
