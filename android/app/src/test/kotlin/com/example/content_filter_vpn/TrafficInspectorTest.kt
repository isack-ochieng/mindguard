package com.example.content_filter_vpn

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TrafficInspectorTest {

    @Test
    fun extractsHttpHostCaseInsensitively() {
        val request = """
            GET / HTTP/1.1
            hOsT: Example.COM:443
            Connection: close

        """.trimIndent().replace("\n", "\r\n").toByteArray()

        assertEquals(
            "example.com",
            TrafficInspector.extractHost(80, request)
        )
    }

    @Test
    fun extractsTlsServerNameIndication() {
        val clientHello = tlsClientHello("blocked.example")
        assertEquals(
            "blocked.example",
            TrafficInspector.extractHost(443, clientHello)
        )
    }

    @Test
    fun extractsDnsQuestionName() {
        val query = byteArrayOf(
            0x12, 0x34, // ID
            0x01, 0x00, // standard query
            0x00, 0x01, // QDCOUNT
            0x00, 0x00, // ANCOUNT
            0x00, 0x00, // NSCOUNT
            0x00, 0x00, // ARCOUNT
            0x07, 'p'.code.toByte(), 'o'.code.toByte(), 'r'.code.toByte(),
            'n'.code.toByte(), 'h'.code.toByte(), 'u'.code.toByte(), 'b'.code.toByte(),
            0x03, 'c'.code.toByte(), 'o'.code.toByte(), 'm'.code.toByte(),
            0x00,
            0x00, 0x01, // A
            0x00, 0x01  // IN
        )

        assertEquals(
            "pornhub.com",
            TrafficInspector.extractDnsQueryName(query)
        )
    }

    @Test
    fun malformedTlsReturnsNull() {
        val malformed = byteArrayOf(
            0x16, 0x03, 0x03, 0x00, 0x20,
            0x01, 0x00, 0x00
        )

        assertNull(TrafficInspector.extractHost(443, malformed))
    }

    @Test
    fun malformedDnsReturnsNull() {
        val malformed = byteArrayOf(
            0x12, 0x34,
            0x01, 0x00,
            0x00, 0x01,
            0x00, 0x00,
            0x00, 0x00,
            0x00, 0x00,
            0x04, 't'.code.toByte(), 'e'.code.toByte()
        )

        assertNull(TrafficInspector.extractDnsQueryName(malformed))
    }

    private fun tlsClientHello(serverName: String): ByteArray {
        val host = serverName.toByteArray(Charsets.US_ASCII)

        val sniList = byteArrayOf(
            0x00, (host.size + 3).toByte(),
            0x00, host.size.toByte(),
            *host
        )

        val sniExtension = byteArrayOf(
            0x00, 0x00,
            (sniList.size ushr 8).toByte(), (sniList.size and 0xFF).toByte(),
            *sniList
        )

        val extensions = byteArrayOf(
            (sniExtension.size ushr 8).toByte(),
            (sniExtension.size and 0xFF).toByte(),
            *sniExtension
        )

        val cipherSuites = byteArrayOf(
            0x00, 0x02,
            0x13, 0x01
        )

        val compressionMethods = byteArrayOf(
            0x01,
            0x00
        )

        val clientHelloBody = byteArrayOf(
            0x03, 0x03, // legacy_version
            *ByteArray(32) { 0x01 }, // random
            0x00, // session id length
            *cipherSuites,
            *compressionMethods,
            *extensions
        )

        val handshake = byteArrayOf(
            0x01,
            (clientHelloBody.size ushr 16).toByte(),
            (clientHelloBody.size ushr 8).toByte(),
            (clientHelloBody.size and 0xFF).toByte(),
            *clientHelloBody
        )

        return byteArrayOf(
            0x16,
            0x03, 0x03,
            (handshake.size ushr 8).toByte(),
            (handshake.size and 0xFF).toByte(),
            *handshake
        )
    }
}
