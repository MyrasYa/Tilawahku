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
}
