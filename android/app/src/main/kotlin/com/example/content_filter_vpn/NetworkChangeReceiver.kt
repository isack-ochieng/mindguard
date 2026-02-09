package com.example.content_filter_vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log

class NetworkChangeReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "NetworkChangeReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ConnectivityManager.CONNECTIVITY_ACTION) {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val isConnected = isNetworkConnected(connectivityManager)
            
            Log.d(TAG, "Network state changed. Connected: $isConnected")

            val prefs = context.getSharedPreferences("vpn_prefs", Context.MODE_PRIVATE)
            val isVpnAutoToggleEnabled = prefs.getBoolean("auto_toggle_enabled", false)
            
            if (!isVpnAutoToggleEnabled) {
                Log.d(TAG, "Auto-toggle is disabled. Ignoring network change.")
                return
            }

            val vpnIntent = Intent(context, LocalVpnService::class.java)
            
            if (isConnected) {
                Log.d(TAG, "Network connected. Starting VPN service.")
                vpnIntent.action = LocalVpnService.ACTION_START
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(vpnIntent)
                } else {
                    context.startService(vpnIntent)
                }
            } else {
                Log.d(TAG, "Network disconnected. Stopping VPN service.")
                vpnIntent.action = LocalVpnService.ACTION_STOP
                context.startService(vpnIntent)
            }
        }
    }
    
    private fun isNetworkConnected(cm: ConnectivityManager): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = cm.activeNetwork ?: return false
            val capabilities = cm.getNetworkCapabilities(network) ?: return false
            return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                   capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = cm.activeNetworkInfo ?: return false
            @Suppress("DEPRECATION")
            return networkInfo.isConnected
        }
    }
}
