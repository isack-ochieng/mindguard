import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AdminService {
  static const platform = MethodChannel('com.contentfilter.vpn/admin');
  
  Future<bool> isDeviceAdminEnabled() async {
    try {
      return await platform.invokeMethod<bool>('isDeviceAdminEnabled') ?? false;
    } on PlatformException catch (e) {
      debugPrint("Failed to check device admin status: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> requestDeviceAdmin() async {
    try {
      return await platform.invokeMethod<bool>('requestDeviceAdmin') ?? false;
    } on PlatformException catch (e) {
      debugPrint("Failed to request device admin: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> removeDeviceAdmin() async {
    try {
      return await platform.invokeMethod<bool>('removeDeviceAdmin') ?? false;
    } on PlatformException catch (e) {
      debugPrint("Failed to remove device admin: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> setAppAsSystemApp() async {
    try {
      // This requires root access and is not recommended for production
      return await platform.invokeMethod<bool>('setAppAsSystemApp') ?? false;
    } on PlatformException catch (e) {
      debugPrint("Failed to set app as system app: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> enableAppLock() async {
    try {
      return await platform.invokeMethod<bool>('enableAppLock') ?? false;
    } on PlatformException catch (e) {
      debugPrint("Failed to enable app lock: '${e.message}'.");
      return false;
    }
  }
}
