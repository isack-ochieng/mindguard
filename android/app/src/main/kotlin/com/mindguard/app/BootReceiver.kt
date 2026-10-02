package com.mindguard.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            // Check if VPN was previously enabled
            val prefs = context.getSharedPreferences("vpn_prefs", Context.MODE_PRIVATE)
            val wasVpnEnabled = prefs.getBoolean("vpn_enabled", false)
            
            if (wasVpnEnabled) {
                // Restart VPN service
                val serviceIntent = Intent(context, LocalVpnService::class.java)
                serviceIntent.action = LocalVpnService.ACTION_START
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}
