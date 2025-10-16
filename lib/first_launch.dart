import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String firstLaunchKey = "isFirstLaunch";

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(firstLaunchKey) ?? true;
  }

  static Future<void> setLaunched() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(firstLaunchKey, false);
  }
}
