package com.example.content_filter_vpn

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VPN_CHANNEL = "com.contentfilter.vpn/service"
    private val ADMIN_CHANNEL = "com.contentfilter.vpn/admin"
    private val VPN_REQUEST_CODE = 1001
    private val ADMIN_REQUEST_CODE = 1002
    
    private var vpnMethodChannel: MethodChannel? = null
    private var adminMethodChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName
    
    private val connectionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.example.content_filter_vpn.CONNECTION_STATE" -> {
                    val connected = intent.getBooleanExtra("connected", false)
                    vpnMethodChannel?.invokeMethod("onConnectionStateChanged", connected)
                }
                "com.example.content_filter_vpn.SITE_BLOCKED" -> {
                    val url = intent.getStringExtra("url")
                    vpnMethodChannel?.invokeMethod("onSiteBlocked", url)
                }
            }
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize device policy manager
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, AdminReceiver::class.java)
        
        // VPN Channel
        vpnMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
        vpnMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    startVpn(result)
                }
                "stopVpn" -> {
                    stopVpn(result)
                }
                "checkVpnPermission" -> {
                    result.success(checkVpnPermission())
                }
                "requestVpnPermission" -> {
                    requestVpnPermission(result)
                }
                "updateBlockedDomains" -> {
                    val domains = call.argument<List<String>>("domains")
                    updateBlockedDomains(domains ?: emptyList())
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Admin Channel
        adminMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADMIN_CHANNEL)
        adminMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceAdminEnabled" -> {
                    result.success(isDeviceAdminEnabled())
                }
                "requestDeviceAdmin" -> {
                    requestDeviceAdmin(result)
                }
                "removeDeviceAdmin" -> {
                    removeDeviceAdmin()
                    result.success(true)
                }
                "enableAppLock" -> {
                    result.success(enableAppLock())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Register broadcast receiver
        val filter = IntentFilter().apply {
            addAction("com.example.content_filter_vpn.CONNECTION_STATE")
            addAction("com.example.content_filter_vpn.SITE_BLOCKED")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(connectionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(connectionReceiver, filter)
        }
    }
    
    // VPN Methods
    private fun checkVpnPermission(): Boolean {
        val intent = VpnService.prepare(this)
        return intent == null
    }
    
    private fun requestVpnPermission(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingResult = result
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            result.success(true)
        }
    }
    
    private fun startVpn(result: MethodChannel.Result) {
        if (!checkVpnPermission()) {
            result.error("PERMISSION_DENIED", "VPN permission not granted", null)
            return
        }
        
        val intent = Intent(this, LocalVpnService::class.java)
        intent.action = LocalVpnService.ACTION_START
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        
        result.success(true)
    }
    
    private fun stopVpn(result: MethodChannel.Result) {
        val intent = Intent(this, LocalVpnService::class.java)
        intent.action = LocalVpnService.ACTION_STOP
        startService(intent)
        result.success(true)
    }
    
    private fun updateBlockedDomains(domains: List<String>) {
        val intent = Intent(this, LocalVpnService::class.java)
        intent.action = LocalVpnService.ACTION_UPDATE_DOMAINS
        intent.putStringArrayListExtra(LocalVpnService.EXTRA_DOMAINS, ArrayList(domains))
        startService(intent)
    }
    
    // Admin Methods
    private fun isDeviceAdminEnabled(): Boolean {
        return devicePolicyManager.isAdminActive(adminComponent)
    }
    
    private fun requestDeviceAdmin(result: MethodChannel.Result) {
        if (isDeviceAdminEnabled()) {
            result.success(true)
            return
        }
        
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
        intent.putExtra(
            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
            "This app requires device admin privileges to prevent unauthorized uninstallation and ensure content filtering remains active."
        )
        
        pendingResult = result
        startActivityForResult(intent, ADMIN_REQUEST_CODE)
    }
    
    private fun removeDeviceAdmin() {
        if (isDeviceAdminEnabled()) {
            devicePolicyManager.removeActiveAdmin(adminComponent)
        }
    }
    
    private fun enableAppLock(): Boolean {
        // This would require additional implementation
        // For now, we'll just return the admin status
        return isDeviceAdminEnabled()
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            VPN_REQUEST_CODE -> {
                if (resultCode == Activity.RESULT_OK) {
                    pendingResult?.success(true)
                } else {
                    pendingResult?.error("PERMISSION_DENIED", "User denied VPN permission", null)
                }
                pendingResult = null
            }
            ADMIN_REQUEST_CODE -> {
                if (resultCode == Activity.RESULT_OK) {
                    pendingResult?.success(true)
                } else {
                    pendingResult?.error("ADMIN_DENIED", "User denied device admin permission", null)
                }
                pendingResult = null
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(connectionReceiver)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
