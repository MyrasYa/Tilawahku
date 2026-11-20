import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  const AppPreferences();

  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _selectedVoiceKey = 'selected_voice_id';
  static const _darkModeKey = 'dark_mode';
  static const _translationVisibleKey = 'translation_visible';
  static const _arabicTextScaleKey = 'arabic_text_scale';

  Future<bool> get onboardingComplete async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompleteKey, value);
  }

  Future<String?> get selectedVoiceId async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_selectedVoiceKey);
  }

  Future<void> setSelectedVoiceId(String id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedVoiceKey, id);
  }

  Future<bool> get darkMode async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_darkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeKey, value);
  }

  Future<bool> get translationVisible async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_translationVisibleKey) ?? true;
  }

  Future<void> setTranslationVisible(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_translationVisibleKey, value);
  }

  Future<double> get arabicTextScale async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble(_arabicTextScaleKey) ?? 1;
  }

  Future<void> setArabicTextScale(double value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_arabicTextScaleKey, value);
  }

  // Kunci generik untuk fitur di luar pembacaan Al-Qur'an (mis. pengaturan
  // waktu sholat) agar semua preferensi tetap lewat satu penyimpanan.
  Future<String?> getString(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  Future<void> setString(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value);
  }

  Future<bool?> getBool(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(key);
  }

  Future<void> setBool(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }

  Future<int?> getInt(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(key);
  }

  Future<void> setInt(String key, int value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(key, value);
  }

  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
