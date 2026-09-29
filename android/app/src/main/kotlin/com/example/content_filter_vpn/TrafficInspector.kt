package com.example.content_filter_vpn

import java.nio.charset.StandardCharsets
import java.util.Locale

object TrafficInspector {
    private const val MAX_INSPECTION_BYTES = 32 * 1024
    private const val TLS_HANDSHAKE_CONTENT_TYPE = 22
    private const val TLS_CLIENT_HELLO = 1
    private const val TLS_SNI_EXTENSION = 0x0000
    private const val TLS_ECH_EXTENSION = 0xFE0D
    private const val HTTP_PORT = 80
    private const val HTTPS_PORT = 443

    data class TlsInspectionResult(
        val host: String?,
        val encryptedClientHello: Boolean,
        val complete: Boolean
    )

    fun extractHost(destinationPort: Int, payload: ByteArray): String? {
        if (payload.isEmpty()) return null

        return when (destinationPort) {
            HTTP_PORT -> extractHttpHost(payload)
            HTTPS_PORT -> inspectTlsClientHello(payload).host
            else -> null
        }?.let(::normalizeHost)
    }

    fun inspectTlsClientHello(payload: ByteArray): TlsInspectionResult {
        val size = minOf(payload.size, MAX_INSPECTION_BYTES)
        if (size < 5) {
            return TlsInspectionResult(null, false, false)
        }

        if ((payload[0].toInt() and 0xFF) != TLS_HANDSHAKE_CONTENT_TYPE) {
            return TlsInspectionResult(null, false, true)
        }

        val recordLength = readUInt16(payload, 3)
        if (5 + recordLength > size) {
            return TlsInspectionResult(null, false, false)
        }

        var offset = 5
        if ((payload[offset].toInt() and 0xFF) != TLS_CLIENT_HELLO) {
            return TlsInspectionResult(null, false, true)
        }
        offset++

        if (offset + 3 > size) {
            return TlsInspectionResult(null, false, false)
        }

        val handshakeLength = readUInt24(payload, offset)
        offset += 3

        val handshakeEnd = offset + handshakeLength
        if (handshakeEnd > size) {
            return TlsInspectionResult(null, false, false)
        }

        if (offset + 34 > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }
        offset += 34

        if (offset + 1 > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }
        val sessionIdLength = payload[offset].toInt() and 0xFF
        offset++
        if (offset + sessionIdLength > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }
        offset += sessionIdLength

        if (offset + 2 > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }
        val cipherSuitesLength = readUInt16(payload, offset)
        offset += 2
        if (offset + cipherSuitesLength > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }
        offset += cipherSuitesLength

        if (offset + 1 > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }
        val compressionLength = payload[offset].toInt() and 0xFF
        offset++
        if (offset + compressionLength > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }
        offset += compressionLength

        if (offset + 2 > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }
        val extensionsLength = readUInt16(payload, offset)
        offset += 2

        val extensionsEnd = offset + extensionsLength
        if (extensionsEnd > handshakeEnd) {
            return TlsInspectionResult(null, false, false)
        }

        var sni: String? = null
        var encryptedClientHello = false

        while (offset + 4 <= extensionsEnd) {
            val extensionType = readUInt16(payload, offset)
            val extensionLength = readUInt16(payload, offset + 2)
            offset += 4

            if (offset + extensionLength > extensionsEnd) {
                return TlsInspectionResult(null, encryptedClientHello, false)
            }

            when (extensionType) {
                TLS_SNI_EXTENSION -> {
                    sni = parseServerNameExtension(payload, offset, extensionLength)
                }
                TLS_ECH_EXTENSION -> {
                    encryptedClientHello = true
                }
            }

            offset += extensionLength
        }

        return TlsInspectionResult(
            host = sni?.let(::normalizeHost),
            encryptedClientHello = encryptedClientHello,
            complete = true
        )
    }

    fun extractDnsQueryName(payload: ByteArray): String? {
        if (payload.size < 12) return null
        if (readUInt16(payload, 4) < 1) return null

        var offset = 12
        val labels = mutableListOf<String>()

        while (offset < payload.size) {
            val length = payload[offset].toInt() and 0xFF
            offset++

            if (length == 0) break
            if (length > 63 || offset + length > payload.size) return null

            val label = payload.copyOfRange(offset, offset + length)
                .toString(StandardCharsets.US_ASCII)

            if (label.isEmpty()) return null
            labels += label
            offset += length
        }

        if (labels.isEmpty() || offset + 4 > payload.size) return null
        return normalizeHost(labels.joinToString("."))
    }

    private fun extractHttpHost(payload: ByteArray): String? {
        val length = minOf(payload.size, MAX_INSPECTION_BYTES)
        val text = payload.copyOf(length).toString(StandardCharsets.ISO_8859_1)

        var lineStart = 0
        while (lineStart < text.length) {
            val lineEnd = text.indexOf("\r\n", lineStart)
                .let { if (it >= 0) it else text.length }

            val line = text.substring(lineStart, lineEnd)
            val colon = line.indexOf(':')

            if (colon > 0 && line.substring(0, colon).equals("Host", ignoreCase = true)) {
                return line.substring(colon + 1).trim()
            }

            if (lineEnd >= text.length) break
            lineStart = lineEnd + 2
        }

        return null
    }

    private fun parseServerNameExtension(
        payload: ByteArray,
        offset: Int,
        length: Int
    ): String? {
        if (length < 5 || offset + length > payload.size) return null

        var cursor = offset
        val listLength = readUInt16(payload, cursor)
        cursor += 2

        if (listLength + 2 > length) return null
        val listEnd = cursor + listLength

        while (cursor + 3 <= listEnd) {
            val nameType = payload[cursor].toInt() and 0xFF
            val nameLength = readUInt16(payload, cursor + 1)
            cursor += 3

            if (cursor + nameLength > listEnd) return null

            if (nameType == 0) {
                return payload.copyOfRange(cursor, cursor + nameLength)
                    .toString(StandardCharsets.US_ASCII)
            }

            cursor += nameLength
        }

        return null
    }

    private fun normalizeHost(raw: String): String? {
        var host = raw.trim().lowercase(Locale.US)

        if (host.startsWith("https://")) host = host.removePrefix("https://")
        if (host.startsWith("http://")) host = host.removePrefix("http://")

        host = host.substringBefore('/')
        host = host.substringBefore(':')
        host = host.trimEnd('.')

        return host.takeIf {
            it.isNotEmpty() &&
                it.length <= 253 &&
                it.none(Char::isWhitespace)
        }
    }

    private fun readUInt16(data: ByteArray, offset: Int): Int {
        return ((data[offset].toInt() and 0xFF) shl 8) or
            (data[offset + 1].toInt() and 0xFF)
    }

    private fun readUInt24(data: ByteArray, offset: Int): Int {
        return ((data[offset].toInt() and 0xFF) shl 16) or
            ((data[offset + 1].toInt() and 0xFF) shl 8) or
            (data[offset + 2].toInt() and 0xFF)
    }
}
