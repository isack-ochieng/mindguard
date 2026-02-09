import 'package:shared_preferences/shared_preferences.dart';

class NetworkService {
  static const String _autoToggleKey = 'auto_toggle_enabled';

  Future<bool> isAutoToggleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoToggleKey) ?? false;
  }

  Future<bool> setAutoToggleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_autoToggleKey, enabled);
  }
}
