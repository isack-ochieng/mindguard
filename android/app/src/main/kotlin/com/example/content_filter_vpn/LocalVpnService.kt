package com.example.content_filter_vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Lightweight demo VPN.
 *
 * This version intentionally does DNS-only filtering:
 * - no TLS inspection
 * - no tun2socks/HEV tunnel
 * - no packet payload inspection
 * - no browsing telemetry
 *
 * Only DNS packets destined for 10.0.0.1 are processed here. Allowed DNS
 * queries are forwarded through a protected socket and normal application
 * traffic remains on the device's ordinary network path.
 */
class LocalVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private lateinit var dnsResolver: DnsResolver

    private val running = AtomicBoolean(false)

    companion object {
        const val ACTION_START = "com.example.content_filter_vpn.START"
        const val ACTION_STOP = "com.example.content_filter_vpn.STOP"
        const val ACTION_UPDATE_DOMAINS = "com.example.content_filter_vpn.UPDATE_DOMAINS"
        const val EXTRA_DOMAINS = "domains"

        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "mindguard_dns"
        private const val VPN_MTU = 1500
        private const val VPN_ADDRESS = "10.0.0.2"
        private const val LOCAL_DNS = "10.0.0.1"
        private const val UPSTREAM_DNS = "1.1.1.1"
        private const val DNS_PORT = 53
        private const val DNS_TIMEOUT_MS = 1500
    }

    override fun onCreate() {
        super.onCreate()
        dnsResolver = DnsResolver(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startVpnService()
            ACTION_STOP -> stopVpnService()
            ACTION_UPDATE_DOMAINS -> {
                val domains = intent.getStringArrayListExtra(EXTRA_DOMAINS)
                dnsResolver.updateBlockedDomains(domains ?: emptyList())
            }
        }
        return START_STICKY
    }

    @Synchronized
    private fun startVpnService() {
        if (running.get()) return

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())

        try {
            vpnInterface = Builder()
                .addAddress(VPN_ADDRESS, 24)
                // Route only our private DNS endpoint into the VPN.
                .addRoute(LOCAL_DNS, 32)
                .addDnsServer(LOCAL_DNS)
                // Let IPv6 traffic fall through instead of building a partial
                // IPv6 tunnel that could make the whole phone feel slower.
                .allowFamily(OsConstants.AF_INET6)
                // MindGuard's own HTTP/Gemini connection must stay outside VPN.
                .addDisallowedApplication(packageName)
                .setSession("MindGuard DNS")
                .setMtu(VPN_MTU)
                // Blocking read = no busy polling / 1 ms sleep loop.
                .setBlocking(true)
                .establish()
                ?: throw IllegalStateException("VPN interface could not be established")

            running.set(true)
            vpnThread = Thread(::runDnsLoop, "MindGuard-DNS").also { it.start() }

            sendConnectionState(true)
        } catch (e: Exception) {
            e.printStackTrace()
            stopVpnService()
        }
    }

    private fun runDnsLoop() {
        val pfd = vpnInterface ?: return

        try {
            FileInputStream(pfd.fileDescriptor).use { input ->
                FileOutputStream(pfd.fileDescriptor).use { output ->
                    val packetBuffer = ByteArray(VPN_MTU)

                    while (running.get()) {
                        val length = input.read(packetBuffer)
                        if (length <= 0) continue

                        val response = handleDnsPacket(packetBuffer, length)
                        if (response != null) {
                            output.write(response)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            if (running.get()) e.printStackTrace()
        }
    }

    private fun handleDnsPacket(packet: ByteArray, length: Int): ByteArray? {
        if (length < 28) return null

        val version = (packet[0].toInt() ushr 4) and 0x0F
        val ihl = (packet[0].toInt() and 0x0F) * 4
        if (version != 4 || ihl < 20 || length < ihl + 8) return null

        if ((packet[9].toInt() and 0xFF) != 17) return null

        val localDnsBytes = parseIpv4(LOCAL_DNS)
        if (!packet.copyOfRange(16, 20).contentEquals(localDnsBytes)) return null

        val udpOffset = ihl
        val sourceIp = packet.copyOfRange(12, 16)
        val sourcePort = readU16(packet, udpOffset)
        val destinationPort = readU16(packet, udpOffset + 2)

        if (destinationPort != DNS_PORT) return null

        val dnsOffset = udpOffset + 8
        if (length <= dnsOffset + 12) return null

        val dnsQuery = packet.copyOfRange(dnsOffset, length)
        val question = parseDnsQuestion(dnsQuery) ?: return null
        val decision = dnsResolver.decideDomain(question.domain)

        val dnsResponse = when (decision.action) {
            DecisionAction.BLOCK -> {
                sendBlockedSite(question.domain)
                buildNxDomain(dnsQuery, question.questionEnd)
            }

            DecisionAction.ALLOW,
            DecisionAction.UNKNOWN -> forwardDnsQuery(dnsQuery)
        } ?: return null

        return buildIpv4UdpPacket(
            sourceIp = localDnsBytes,
            destinationIp = sourceIp,
            sourcePort = DNS_PORT,
            destinationPort = sourcePort,
            payload = dnsResponse
        )
    }

    /**
     * This is the only outbound network work performed by the VPN.
     * The socket is protected so the query cannot loop back through the VPN.
     */
    private fun forwardDnsQuery(query: ByteArray): ByteArray? {
        return runCatching {
            DatagramSocket().use { socket ->
                if (!protect(socket)) return null

                socket.soTimeout = DNS_TIMEOUT_MS

                val request = DatagramPacket(
                    query,
                    query.size,
                    InetAddress.getByName(UPSTREAM_DNS),
                    DNS_PORT
                )
                socket.send(request)

                val responseBytes = ByteArray(2048)
                val responsePacket = DatagramPacket(
                    responseBytes,
                    responseBytes.size
                )
                socket.receive(responsePacket)

                responsePacket.data.copyOf(responsePacket.length)
            }
        }.getOrNull()
    }

    private data class ParsedQuestion(
        val domain: String,
        val questionEnd: Int
    )

    private fun parseDnsQuestion(query: ByteArray): ParsedQuestion? {
        if (query.size < 17) return null

        var position = 12
        val labels = mutableListOf<String>()

        while (position < query.size) {
            val labelLength = query[position].toInt() and 0xFF

            if (labelLength == 0) {
                position += 1
                break
            }

            if (labelLength > 63 || position + labelLength + 1 > query.size) {
                return null
            }

            val labelStart = position + 1
            labels += String(
                query,
                labelStart,
                labelLength,
                Charsets.US_ASCII
            )
            position += labelLength + 1
        }

        if (labels.isEmpty() || position + 4 > query.size) return null

        position += 4 // QTYPE + QCLASS

        val domain = labels.joinToString(".").lowercase()
        if (domain.isBlank()) return null

        return ParsedQuestion(domain, position)
    }

    private fun buildNxDomain(query: ByteArray, questionEnd: Int): ByteArray {
        val response = query.copyOf(questionEnd)

        // QR=1, RD=1, RA=1, RCODE=3 (NXDOMAIN).
        response[2] = 0x81.toByte()
        response[3] = 0x83.toByte()

        response[4] = 0
        response[5] = 1
        response[6] = 0
        response[7] = 0
        response[8] = 0
        response[9] = 0
        response[10] = 0
        response[11] = 0

        return response
    }

    private fun buildIpv4UdpPacket(
        sourceIp: ByteArray,
        destinationIp: ByteArray,
        sourcePort: Int,
        destinationPort: Int,
        payload: ByteArray
    ): ByteArray {
        val ipLength = 20
        val udpLength = 8 + payload.size
        val totalLength = ipLength + udpLength
        val packet = ByteArray(totalLength)

        packet[0] = 0x45
        writeU16(packet, 2, totalLength)
        writeU16(packet, 4, 0)
        writeU16(packet, 6, 0x4000)
        packet[8] = 64
        packet[9] = 17

        System.arraycopy(sourceIp, 0, packet, 12, 4)
        System.arraycopy(destinationIp, 0, packet, 16, 4)

        writeU16(packet, 10, internetChecksum(packet, 0, ipLength))

        writeU16(packet, 20, sourcePort)
        writeU16(packet, 22, destinationPort)
        writeU16(packet, 24, udpLength)
        writeU16(packet, 26, 0)
        System.arraycopy(payload, 0, packet, 28, payload.size)

        val checksum = udpChecksum(
            sourceIp = sourceIp,
            destinationIp = destinationIp,
            udpPacket = packet,
            udpOffset = 20,
            udpLength = udpLength
        )
        writeU16(packet, 26, if (checksum == 0) 0xFFFF else checksum)

        return packet
    }

    private fun udpChecksum(
        sourceIp: ByteArray,
        destinationIp: ByteArray,
        udpPacket: ByteArray,
        udpOffset: Int,
        udpLength: Int
    ): Int {
        var sum = 0L

        for (i in 0 until 4 step 2) {
            sum += ((sourceIp[i].toInt() and 0xFF) shl 8 or
                (sourceIp[i + 1].toInt() and 0xFF)).toLong()
            sum += ((destinationIp[i].toInt() and 0xFF) shl 8 or
                (destinationIp[i + 1].toInt() and 0xFF)).toLong()
        }

        sum += 17L
        sum += udpLength.toLong()

        var index = udpOffset
        val end = udpOffset + udpLength

        while (index + 1 < end) {
            if (index == udpOffset + 6) {
                index += 2
                continue
            }

            sum += ((udpPacket[index].toInt() and 0xFF) shl 8 or
                (udpPacket[index + 1].toInt() and 0xFF)).toLong()
            index += 2
        }

        if (index < end) {
            sum += ((udpPacket[index].toInt() and 0xFF) shl 8).toLong()
        }

        return foldChecksum(sum)
    }

    private fun internetChecksum(
        bytes: ByteArray,
        offset: Int,
        length: Int
    ): Int {
        var sum = 0L
        var index = offset
        val end = offset + length

        while (index + 1 < end) {
            sum += ((bytes[index].toInt() and 0xFF) shl 8 or
                (bytes[index + 1].toInt() and 0xFF)).toLong()
            index += 2
        }

        if (index < end) {
            sum += ((bytes[index].toInt() and 0xFF) shl 8).toLong()
        }

        return foldChecksum(sum)
    }

    private fun foldChecksum(value: Long): Int {
        var sum = value
        while ((sum ushr 16) != 0L) {
            sum = (sum and 0xFFFF) + (sum ushr 16)
        }
        return (sum.inv() and 0xFFFF).toInt()
    }

    private fun readU16(bytes: ByteArray, offset: Int): Int {
        return ((bytes[offset].toInt() and 0xFF) shl 8) or
            (bytes[offset + 1].toInt() and 0xFF)
    }

    private fun writeU16(bytes: ByteArray, offset: Int, value: Int) {
        bytes[offset] = (value ushr 8).toByte()
        bytes[offset + 1] = value.toByte()
    }

    private fun parseIpv4(address: String): ByteArray {
        return address.split('.').map { it.toInt().toByte() }.toByteArray()
    }

    @Synchronized
    private fun stopVpnService() {
        running.set(false)

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        vpnInterface = null

        try {
            vpnThread?.interrupt()
        } catch (_: Exception) {
        }
        vpnThread = null

        sendConnectionState(false)
        stopForeground(true)
        stopSelf()
    }

    private fun updateBlockedDomains(domains: List<String>) {
        dnsResolver.updateBlockedDomains(domains)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MindGuard protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Local DNS content filtering"
                setShowBadge(false)
            }

            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MindGuard")
            .setContentText("Local DNS protection active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun sendConnectionState(connected: Boolean) {
        val intent = Intent("com.example.content_filter_vpn.CONNECTION_STATE")
        intent.putExtra("connected", connected)
        sendBroadcast(intent)
    }

    private fun sendBlockedSite(url: String) {
        val intent = Intent("com.example.content_filter_vpn.SITE_BLOCKED")
        intent.putExtra("url", url)
        sendBroadcast(intent)
    }

    override fun onRevoke() {
        stopVpnService()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopVpnService()
        super.onDestroy()
    }
}
