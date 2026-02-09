import 'dart:async';
import 'package:flutter/services.dart';

class VpnService {
  static const platform = MethodChannel('com.contentfilter.vpn/service');
  
  bool _isConnected = false;
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  final StreamController<String> _blockedSitesController = StreamController<String>.broadcast();
  
  bool get isConnected => _isConnected;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<String> get blockedSitesStream => _blockedSitesController.stream;
  
  VpnService() {
    platform.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onConnectionStateChanged':
        _isConnected = call.arguments as bool;
        _connectionStateController.add(_isConnected);
        break;
      case 'onSiteBlocked':
        final String blockedUrl = call.arguments as String;
        _blockedSitesController.add(blockedUrl);
        break;
    }
  }
  
  Future<bool> startVpn() async {
    try {
      final bool result = await platform.invokeMethod('startVpn');
      _isConnected = result;
      _connectionStateController.add(_isConnected);
      return result;
    } on PlatformException catch (e) {
      print("Failed to start VPN: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> stopVpn() async {
    try {
      final bool result = await platform.invokeMethod('stopVpn');
      _isConnected = !result;
      _connectionStateController.add(_isConnected);
      return result;
    } on PlatformException catch (e) {
      print("Failed to stop VPN: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> checkVpnPermission() async {
    try {
      return await platform.invokeMethod('checkVpnPermission');
    } on PlatformException catch (e) {
      print("Failed to check VPN permission: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> requestVpnPermission() async {
    try {
      return await platform.invokeMethod('requestVpnPermission');
    } on PlatformException catch (e) {
      print("Failed to request VPN permission: '${e.message}'.");
      return false;
    }
  }
  
  Future<void> updateBlockedDomains(List<String> domains) async {
    try {
      await platform.invokeMethod('updateBlockedDomains', {'domains': domains});
    } on PlatformException catch (e) {
      print("Failed to update blocked domains: '${e.message}'.");
    }
  }
  
  void dispose() {
    _connectionStateController.close();
    _blockedSitesController.close();
  }
}
