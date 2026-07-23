import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static AppSettings? _instance;
  late SharedPreferences _prefs;

  AppSettings._();

  static Future<AppSettings> getInstance() async {
    if (_instance == null) {
      _instance = AppSettings._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  static AppSettings get instance {
    assert(_instance != null, 'AppSettings not initialized. Call getInstance() first.');
    return _instance!;
  }

  int get slideshowIntervalSeconds => _prefs.getInt('slideshow_interval') ?? 5;
  set slideshowIntervalSeconds(int value) => _prefs.setInt('slideshow_interval', value);

  bool get slideshowAutoplay => _prefs.getBool('slideshow_autoplay') ?? true;
  set slideshowAutoplay(bool value) => _prefs.setBool('slideshow_autoplay', value);
}
