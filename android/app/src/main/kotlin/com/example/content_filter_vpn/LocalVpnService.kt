package com.example.content_filter_vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap

class LocalVpnService : VpnService() {
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    private val blockedDomains = ConcurrentHashMap<String, Boolean>()
    private var vpnThread: Thread? = null
    private lateinit var dnsResolver: DnsResolver
    private lateinit var packetAnalyzer: PacketAnalyzer
    
    companion object {
        const val ACTION_START = "com.example.content_filter_vpn.START"
        const val ACTION_STOP = "com.example.content_filter_vpn.STOP"
        const val ACTION_UPDATE_DOMAINS = "com.example.content_filter_vpn.UPDATE_DOMAINS"
        const val EXTRA_DOMAINS = "domains"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "vpn_service_channel"
        private const val VPN_MTU = 1500
        private const val VPN_ADDRESS = "10.0.0.2"
    }
    
    override fun onCreate() {
        super.onCreate()
        dnsResolver = DnsResolver(emptySet())
        packetAnalyzer = PacketAnalyzer(dnsResolver)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startVpnService()
            }
            ACTION_STOP -> {
                stopVpnService()
            }
            ACTION_UPDATE_DOMAINS -> {
                val domains = intent.getStringArrayListExtra(EXTRA_DOMAINS)
                updateBlockedDomains(domains ?: emptyList())
            }
        }
        return START_STICKY
    }
    
    private fun startVpnService() {
        if (isRunning) return
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        try {
            vpnInterface = Builder()
                .addAddress(VPN_ADDRESS, 24)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
                .setSession("ContentFilterVPN")
                .setMtu(VPN_MTU)
                .setBlocking(false)
                .establish()
            
            isRunning = true
            
            vpnThread = Thread {
                runVpnLoop()
            }
            vpnThread?.start()
            
            sendConnectionState(true)
        } catch (e: Exception) {
            e.printStackTrace()
            stopVpnService()
        }
    }
    
    private fun runVpnLoop() {
        val vpnInput = FileInputStream(vpnInterface?.fileDescriptor)
        val vpnOutput = FileOutputStream(vpnInterface?.fileDescriptor)
        val buffer = ByteBuffer.allocate(VPN_MTU)
        
        try {
            while (isRunning) {
                val length = vpnInput.read(buffer.array())
                if (length > 0) {
                    buffer.limit(length)
                    buffer.position(0)
                    
                    // Analyze packet
                    val packetInfo = packetAnalyzer.analyzePacket(buffer)
                    
                    if (packetInfo != null && packetInfo.shouldBlock) {
                        // Block this packet
                        val blockedUrl = packetInfo.domain ?: packetInfo.destIp
                        sendBlockedSite(blockedUrl)
                        
                        // Optionally send a RST packet or drop silently
                        // For now, we just drop the packet
                    } else {
                        // Forward packet (in a real implementation, you'd forward to actual network)
                        // This is a simplified version - real VPN would need proper routing
                        buffer.position(0)
                        vpnOutput.write(buffer.array(), 0, length)
                    }
                    
                    buffer.clear()
                }
                
                // Small sleep to prevent CPU overuse
                Thread.sleep(1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            try {
                vpnInput.close()
                vpnOutput.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    private fun stopVpnService() {
        isRunning = false
        vpnThread?.interrupt()
        
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        vpnInterface = null
        sendConnectionState(false)
        stopForeground(true)
        stopSelf()
    }
    
    private fun updateBlockedDomains(domains: List<String>) {
        blockedDomains.clear()
        domains.forEach { domain ->
            blockedDomains[domain] = true
        }
        
        // Update DNS resolver with new domains
        dnsResolver = DnsResolver(blockedDomains.keys)
        packetAnalyzer = PacketAnalyzer(dnsResolver)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Content Filter VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN service for content filtering"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
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
            .setContentTitle("Content Filter VPN")
            .setContentText("VPN is active and filtering content")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
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
    
    override fun onDestroy() {
        stopVpnService()
        super.onDestroy()
    }
}
