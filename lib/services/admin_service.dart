import 'package:flutter/services.dart';

class AdminService {
  static const platform = MethodChannel('com.contentfilter.vpn/admin');
  
  Future<bool> isDeviceAdminEnabled() async {
    try {
      return await platform.invokeMethod('isDeviceAdminEnabled');
    } on PlatformException catch (e) {
      print("Failed to check device admin status: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> requestDeviceAdmin() async {
    try {
      return await platform.invokeMethod('requestDeviceAdmin');
    } on PlatformException catch (e) {
      print("Failed to request device admin: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> removeDeviceAdmin() async {
    try {
      return await platform.invokeMethod('removeDeviceAdmin');
    } on PlatformException catch (e) {
      print("Failed to remove device admin: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> setAppAsSystemApp() async {
    try {
      // This requires root access and is not recommended for production
      return await platform.invokeMethod('setAppAsSystemApp');
    } on PlatformException catch (e) {
      print("Failed to set app as system app: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> enableAppLock() async {
    try {
      return await platform.invokeMethod('enableAppLock');
    } on PlatformException catch (e) {
      print("Failed to enable app lock: '${e.message}'.");
      return false;
    }
  }
}
