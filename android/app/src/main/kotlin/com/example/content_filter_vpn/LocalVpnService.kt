package com.example.content_filter_vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import com.wgtunnel.hevtunnel.HevTunnelConfig
import com.wgtunnel.hevtunnel.TProxyService
import java.io.File

class LocalVpnService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    private lateinit var dnsResolver: DnsResolver
    private var directProxy: Socks5DirectProxy? = null
    private var tunnelThread: Thread? = null
    private var hevConfigFile: File? = null

    companion object {
        const val ACTION_START = "com.example.content_filter_vpn.START"
        const val ACTION_STOP = "com.example.content_filter_vpn.STOP"
        const val ACTION_UPDATE_DOMAINS = "com.example.content_filter_vpn.UPDATE_DOMAINS"
        const val EXTRA_DOMAINS = "domains"

        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "clock_protection"
        private const val VPN_MTU = 1500
        private const val VPN_ADDRESS_V4 = "10.0.0.2"
        private const val VPN_ADDRESS_V6 = "fd00::2"
    }

    override fun onCreate() {
        super.onCreate()
        dnsResolver = DnsResolver(this, emptySet())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startVpnService()
            ACTION_STOP -> stopVpnService()
            ACTION_UPDATE_DOMAINS -> {
                val domains = intent.getStringArrayListExtra(EXTRA_DOMAINS)
                updateBlockedDomains(domains ?: emptyList())
            }
        }

        return START_STICKY
    }

    @Synchronized
    private fun startVpnService() {
        if (isRunning) return

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())

        try {
            val builder = Builder()
                .addAddress(VPN_ADDRESS_V4, 24)
                .addAddress(VPN_ADDRESS_V6, 120)
                .addRoute("0.0.0.0", 0)
                .addRoute("::", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
                .setSession("Clock")
                .setMtu(VPN_MTU)
                .setBlocking(false)

            // MindGuard's own outbound connections must not enter its VPN.
            // The proxy also calls protect() on each upstream socket.
            builder.addDisallowedApplication(packageName)

            val establishedInterface = builder.establish()
                ?: throw IllegalStateException("VPN interface could not be established")

            vpnInterface = establishedInterface

            directProxy = Socks5DirectProxy(
                vpnService = this,
                dnsResolver = dnsResolver,
                onBlocked = ::sendBlockedSite
            )

            val proxyPort = directProxy?.start()
                ?: throw IllegalStateException("Local SOCKS5 proxy could not start")

            hevConfigFile = TProxyService.createHevTunnelConfig(
                config = HevTunnelConfig(
                    mtu = VPN_MTU,
                    ipv4 = VPN_ADDRESS_V4,
                    ipv6 = VPN_ADDRESS_V6,
                    address = "127.0.0.1",
                    port = proxyPort,
                    username = "",
                    password = ""
                ),
                cacheDirPath = cacheDir
            )

            isRunning = true

            val fd = vpnInterface?.fileDescriptor
                ?: throw IllegalStateException("VPN file descriptor unavailable")

            tunnelThread = Thread {
                try {
                    val started = TProxyService.TProxyStartService(
                        hevConfigFile?.absolutePath,
                        fd.detachFd()
                    )

                    if (!started) {
                        throw IllegalStateException("tun2socks engine failed to start")
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    if (isRunning) {
                        isRunning = false
                        sendConnectionState(false)
                    }
                }
            }.apply {
                name = "MindGuard-Tun2Socks"
                start()
            }

            sendConnectionState(true)
        } catch (e: Exception) {
            e.printStackTrace()
            stopVpnService()
        }
    }

    @Synchronized
    private fun stopVpnService() {
        if (!isRunning && vpnInterface == null && directProxy == null) {
            return
        }

        isRunning = false

        try {
            TProxyService.TProxyStopService()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            directProxy?.stop()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        directProxy = null

        try {
            tunnelThread?.interrupt()
        } catch (_: Exception) {
        }
        tunnelThread = null

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        vpnInterface = null

        hevConfigFile?.delete()
        hevConfigFile = null

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
                "Clock protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background network protection"
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
            .setContentTitle("Clock")
            .setContentText("Protection active")
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

    override fun onBind(intent: Intent?): IBinder? {
        return super.onBind(intent)
    }
}
