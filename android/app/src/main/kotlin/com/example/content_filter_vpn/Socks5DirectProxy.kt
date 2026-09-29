package com.example.content_filter_vpn

import android.net.ConnectivityManager
import android.net.Network
import android.net.VpnService
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.EOFException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class Socks5DirectProxy(
    private val vpnService: VpnService,
    private val dnsResolver: DnsResolver,
    private val onBlocked: (String) -> Unit
) {
    companion object {
        private const val SOCKS_VERSION = 5
        private const val NO_AUTH = 0
        private const val METHOD_NOT_ACCEPTABLE = 0xFF
        private const val CMD_CONNECT = 1
        private const val CMD_UDP_ASSOCIATE = 3
        private const val ATYP_IPV4 = 1
        private const val ATYP_DOMAIN = 3
        private const val ATYP_IPV6 = 4
        private const val CONNECT_TIMEOUT_MS = 6_000
        private const val INITIAL_READ_TIMEOUT_MS = 1_200
        private const val HANDSHAKE_TIMEOUT_MS = 5_000
    }

    private val executor: ExecutorService = Executors.newCachedThreadPool()
    private val running = AtomicBoolean(false)
    private var serverSocket: ServerSocket? = null

    val port: Int
        get() = serverSocket?.localPort ?: 0

    fun start(): Int {
        if (running.getAndSet(true)) return port

        val server = ServerSocket()
        server.reuseAddress = true
        server.bind(InetSocketAddress(InetAddress.getLoopbackAddress(), 0))
        serverSocket = server

        executor.execute {
            while (running.get()) {
                try {
                    val client = server.accept()
                    executor.execute { handleClient(client) }
                } catch (_: IOException) {
                    if (running.get()) {
                        // Stop path closes the server socket deliberately.
                    }
                }
            }
        }

        return server.localPort
    }

    fun stop() {
        if (!running.getAndSet(false)) return

        try {
            serverSocket?.close()
        } catch (_: IOException) {
        }

        serverSocket = null
        executor.shutdownNow()
    }

    private fun handleClient(client: Socket) {
        client.use { socket ->
            try {
                socket.soTimeout = HANDSHAKE_TIMEOUT_MS
                val input = BufferedInputStream(socket.getInputStream())
                val output = BufferedOutputStream(socket.getOutputStream())

                if (!negotiate(input, output)) return
                val request = readRequest(input) ?: return

                when (request.command) {
                    CMD_CONNECT -> handleConnect(socket, input, output, request)
                    CMD_UDP_ASSOCIATE -> handleUdpAssociate(input, output)
                    else -> writeReply(output, 7)
                }
            } catch (_: EOFException) {
            } catch (_: IOException) {
            } catch (_: Exception) {
            }
        }
    }

    private fun negotiate(input: InputStream, output: OutputStream): Boolean {
        val version = input.read()
        if (version != SOCKS_VERSION) return false

        val methodCount = input.read()
        if (methodCount <= 0 || methodCount > 255) return false

        val methods = ByteArray(methodCount)
        readFully(input, methods)

        if (!methods.any { (it.toInt() and 0xFF) == NO_AUTH }) {
            output.write(byteArrayOf(SOCKS_VERSION.toByte(), METHOD_NOT_ACCEPTABLE.toByte()))
            output.flush()
            return false
        }

        output.write(byteArrayOf(SOCKS_VERSION.toByte(), NO_AUTH.toByte()))
        output.flush()
        return true
    }

    private data class SocksRequest(
        val command: Int,
        val host: String,
        val port: Int,
        val addressType: Int
    )

    private fun readRequest(input: InputStream): SocksRequest? {
        val header = ByteArray(4)
        readFully(input, header)
        if ((header[0].toInt() and 0xFF) != SOCKS_VERSION) return null

        val command = header[1].toInt() and 0xFF
        val addressType = header[3].toInt() and 0xFF

        val host = when (addressType) {
            ATYP_IPV4 -> readInet4(input)
            ATYP_DOMAIN -> {
                val length = input.read()
                if (length <= 0) return null
                val bytes = ByteArray(length)
                readFully(input, bytes)
                String(bytes, Charsets.US_ASCII)
            }
            ATYP_IPV6 -> readInet6(input)
            else -> return null
        }

        val portBytes = ByteArray(2)
        readFully(input, portBytes)
        val port = ((portBytes[0].toInt() and 0xFF) shl 8) or
            (portBytes[1].toInt() and 0xFF)

        return SocksRequest(command, host, port, addressType)
    }

    private fun handleConnect(
        client: Socket,
        input: InputStream,
        output: OutputStream,
        request: SocksRequest
    ) {
        if (request.addressType == ATYP_DOMAIN) {
            val decision = dnsResolver.decideDomain(request.host)
            if (decision.action == DecisionAction.BLOCK) {
                onBlocked(request.host)
                writeReply(output, 2)
                return
            }
        } else if (isIpBlocked(request.host)) {
            onBlocked(request.host)
            writeReply(output, 2)
            return
        }

        writeReply(output, 0)
        output.flush()

        client.soTimeout = if (request.port == 80 || request.port == 443) {
            INITIAL_READ_TIMEOUT_MS
        } else {
            0
        }

        val initialPayload = if (request.port == 80 || request.port == 443) {
            readInitialPayload(input)
        } else {
            ByteArray(0)
        }

        val discoveredHost = TrafficInspector.extractHost(request.port, initialPayload)
        if (discoveredHost != null) {
            val decision = dnsResolver.decideDomain(discoveredHost)
            if (decision.action == DecisionAction.BLOCK) {
                onBlocked(discoveredHost)
                return
            }
        }

        client.soTimeout = 0
        val targetAddress = resolveTarget(request.host) ?: return

        if (isIpBlocked(targetAddress.hostAddress ?: request.host)) {
            onBlocked(discoveredHost ?: request.host)
            return
        }

        val upstream = Socket()

        try {
            if (!vpnService.protect(upstream)) return

            upstream.tcpNoDelay = true
            upstream.keepAlive = true
            upstream.connect(
                InetSocketAddress(targetAddress, request.port),
                CONNECT_TIMEOUT_MS
            )

            val upstreamInput = BufferedInputStream(upstream.getInputStream())
            val upstreamOutput = BufferedOutputStream(upstream.getOutputStream())

            if (initialPayload.isNotEmpty()) {
                upstreamOutput.write(initialPayload)
                upstreamOutput.flush()
            }

            executor.execute {
                try {
                    copyStream(upstreamInput, client.getOutputStream())
                } catch (_: IOException) {
                } finally {
                    closeQuietly(client)
                }
            }

            try {
                copyStream(input, upstreamOutput)
            } catch (_: IOException) {
            }
        } finally {
            closeQuietly(upstream)
        }
    }

    private fun handleUdpAssociate(
        input: InputStream,
        output: OutputStream
    ) {
        val relay = DatagramSocket(null)

        try {
            if (!vpnService.protect(relay)) {
                writeReply(output, 1)
                return
            }

            relay.reuseAddress = true
            relay.bind(InetSocketAddress(0))

            val relayPort = relay.localPort
            writeReply(
                output = output,
                reply = 0,
                address = InetAddress.getLoopbackAddress(),
                port = relayPort
            )
            output.flush()

            val associationRunning = AtomicBoolean(true)
            val clientEndpoint = arrayOfNulls<InetSocketAddress>(1)
            val remoteEndpoints = ConcurrentHashMap.newKeySet<String>()

            executor.execute {
                monitorUdpControlConnection(input, associationRunning)
            }

            relay.soTimeout = 1_000
            val packetBuffer = ByteArray(65_535)

            while (running.get() && associationRunning.get()) {
                try {
                    val packet = DatagramPacket(packetBuffer, packetBuffer.size)
                    relay.receive(packet)

                    val sourceKey = endpointKey(packet.address, packet.port)
                    val currentClient = clientEndpoint[0]

                    if (
                        currentClient == null ||
                        sourceKey == endpointKey(currentClient.address, currentClient.port)
                    ) {
                        val request = parseUdpRequest(packet) ?: continue
                        val destination = resolveTarget(request.host) ?: continue

                        if (dnsResolver.isIpBlocked(destination.hostAddress ?: request.host)) {
                            onBlocked(request.domainForEvent ?: request.host)
                            continue
                        }

                        if (request.destinationPort == 53) {
                            val dnsName = TrafficInspector.extractDnsQueryName(request.payload)
                            if (
                                dnsName != null &&
                                dnsResolver.decideDomain(dnsName).action == DecisionAction.BLOCK
                            ) {
                                onBlocked(dnsName)
                                continue
                            }
                        } else if (
                            request.hostIsDomain &&
                            request.domainForEvent != null &&
                            dnsResolver.decideDomain(request.domainForEvent).action == DecisionAction.BLOCK
                        ) {
                            onBlocked(request.domainForEvent)
                            continue
                        }

                        clientEndpoint[0] = InetSocketAddress(packet.address, packet.port)

                        relay.send(
                            DatagramPacket(
                                request.payload,
                                request.payload.size,
                                destination,
                                request.destinationPort
                            )
                        )
                        remoteEndpoints += endpointKey(destination, request.destinationPort)
                    } else if (
                        remoteEndpoints.contains(sourceKey) &&
                        currentClient != null
                    ) {
                        val response = wrapUdpResponse(packet)
                        relay.send(
                            DatagramPacket(
                                response,
                                response.size,
                                currentClient.address,
                                currentClient.port
                            )
                        )
                    }
                } catch (_: java.net.SocketTimeoutException) {
                } catch (_: IOException) {
                    break
                }
            }
        } finally {
            relay.close()
        }
    }

    private data class UdpRequest(
        val host: String,
        val destinationPort: Int,
        val payload: ByteArray,
        val hostIsDomain: Boolean,
        val domainForEvent: String?
    )

    private fun parseUdpRequest(packet: DatagramPacket): UdpRequest? {
        val data = packet.data
        val end = packet.offset + packet.length
        var offset = packet.offset

        if (packet.length < 4) return null
        if (
            data[offset].toInt() != 0 ||
            data[offset + 1].toInt() != 0 ||
            data[offset + 2].toInt() != 0
        ) return null

        val fragment = data[offset + 2].toInt() and 0xFF
        if (fragment != 0) return null

        val addressType = data[offset + 3].toInt() and 0xFF
        offset += 4

        val host = when (addressType) {
            ATYP_IPV4 -> {
                if (offset + 4 > end) return null
                val value = readInet4(data, offset)
                offset += 4
                value
            }
            ATYP_DOMAIN -> {
                if (offset >= end) return null
                val length = data[offset].toInt() and 0xFF
                offset++
                if (length <= 0 || offset + length > end) return null
                val value = String(data, offset, length, Charsets.US_ASCII)
                offset += length
                value
            }
            ATYP_IPV6 -> {
                if (offset + 16 > end) return null
                val value = readInet6(data, offset)
                offset += 16
                value
            }
            else -> return null
        }

        if (offset + 2 > end) return null
        val destinationPort = ((data[offset].toInt() and 0xFF) shl 8) or
            (data[offset + 1].toInt() and 0xFF)
        offset += 2
        if (offset > end) return null

        return UdpRequest(
            host = host,
            destinationPort = destinationPort,
            payload = data.copyOfRange(offset, end),
            hostIsDomain = addressType == ATYP_DOMAIN,
            domainForEvent = if (addressType == ATYP_DOMAIN) host else null
        )
    }

    private fun wrapUdpResponse(packet: DatagramPacket): ByteArray {
        val address = packet.address
        val ipBytes = address.address

        val type = when (address) {
            is Inet4Address -> ATYP_IPV4
            is Inet6Address -> ATYP_IPV6
            else -> ATYP_IPV4
        }

        val headerSize = if (type == ATYP_IPV4) 10 else 22
        val output = ByteArray(headerSize + packet.length)
        val buffer = ByteBuffer.wrap(output)

        buffer.put(0)
        buffer.put(0)
        buffer.put(0)
        buffer.put(type.toByte())
        buffer.put(ipBytes)
        buffer.putShort(packet.port.toShort())
        buffer.put(packet.data, packet.offset, packet.length)

        return output
    }

    private fun monitorUdpControlConnection(
        input: InputStream,
        associationRunning: AtomicBoolean
    ) {
        try {
            while (running.get() && associationRunning.get()) {
                if (input.read() == -1) {
                    associationRunning.set(false)
                    return
                }
            }
        } catch (_: IOException) {
            associationRunning.set(false)
        }
    }

    private fun resolveTarget(host: String): InetAddress? {
        return try {
            val network = getUnderlyingNetwork()
            val normalized = host.removePrefix("[").removeSuffix("]")

            if (
                normalized.matches(Regex("^\\d{1,3}(\\.\\d{1,3}){3}$")) ||
                normalized.contains(':')
            ) {
                InetAddress.getByName(normalized)
            } else {
                network?.getAllByName(normalized)?.firstOrNull()
                    ?: InetAddress.getByName(normalized)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun getUnderlyingNetwork(): Network? {
        val connectivityManager =
            vpnService.getSystemService(ConnectivityManager::class.java)
        return connectivityManager?.activeNetwork
    }

    private fun isIpBlocked(host: String): Boolean {
        return runCatching {
            val normalized = host.removePrefix("[").removeSuffix("]")
            val resolved = InetAddress.getByName(normalized).hostAddress ?: normalized
            dnsResolver.isIpBlocked(resolved)
        }.getOrDefault(false)
    }

    private fun readInitialPayload(input: InputStream): ByteArray {
        val buffer = ByteArray(8192)
        val firstRead = try {
            input.read(buffer)
        } catch (_: java.net.SocketTimeoutException) {
            return ByteArray(0)
        }

        if (firstRead <= 0) return ByteArray(0)
        return buffer.copyOf(firstRead)
    }

    private fun copyStream(input: InputStream, output: OutputStream) {
        val buffer = ByteArray(32 * 1024)

        while (running.get()) {
            val read = input.read(buffer)
            if (read == -1) break
            if (read == 0) continue

            output.write(buffer, 0, read)
            output.flush()
        }
    }

    private fun writeReply(
        output: OutputStream,
        reply: Int,
        address: InetAddress = InetAddress.getByName("0.0.0.0"),
        port: Int = 0
    ) {
        val ipBytes = address.address
        val type = if (address is Inet6Address) ATYP_IPV6 else ATYP_IPV4

        val bytes = java.io.ByteArrayOutputStream()
        bytes.write(SOCKS_VERSION)
        bytes.write(reply)
        bytes.write(0)
        bytes.write(type)
        bytes.write(ipBytes)
        bytes.write((port ushr 8) and 0xFF)
        bytes.write(port and 0xFF)

        output.write(bytes.toByteArray())
        output.flush()
    }

    private fun readInet4(input: InputStream): String {
        val bytes = ByteArray(4)
        readFully(input, bytes)
        return "${bytes[0].toInt() and 0xFF}.${bytes[1].toInt() and 0xFF}.${bytes[2].toInt() and 0xFF}.${bytes[3].toInt() and 0xFF}"
    }

    private fun readInet6(input: InputStream): String {
        val bytes = ByteArray(16)
        readFully(input, bytes)
        return InetAddress.getByAddress(bytes).hostAddress
            ?: throw IOException("Invalid IPv6 address")
    }

    private fun readInet4(data: ByteArray, offset: Int): String {
        return "${data[offset].toInt() and 0xFF}.${data[offset + 1].toInt() and 0xFF}.${data[offset + 2].toInt() and 0xFF}.${data[offset + 3].toInt() and 0xFF}"
    }

    private fun readInet6(data: ByteArray, offset: Int): String {
        val bytes = data.copyOfRange(offset, offset + 16)
        return InetAddress.getByAddress(bytes).hostAddress
            ?: throw IOException("Invalid IPv6 address")
    }

    private fun readFully(input: InputStream, data: ByteArray) {
        var offset = 0
        while (offset < data.size) {
            val read = input.read(data, offset, data.size - offset)
            if (read == -1) throw EOFException()
            offset += read
        }
    }

    private fun endpointKey(address: InetAddress, port: Int): String {
        return "${address.hostAddress}:${port}"
    }

    private fun closeQuietly(socket: Socket) {
        try {
            socket.close()
        } catch (_: IOException) {
        }
    }
}
