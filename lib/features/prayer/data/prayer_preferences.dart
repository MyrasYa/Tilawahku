import 'dart:convert';

import '../../../core/preferences/app_preferences.dart';
import '../domain/prayer_method.dart';
import '../domain/prayer_models.dart';

/// Preferensi fitur waktu sholat, disimpan lewat `AppPreferences` yang sudah ada
/// supaya tidak ada kedua sistem penyimpanan preferensi di aplikasi.
///
/// Nilai yang tidak sah (metode asing, koordinat di luar rentang) dibaca
/// kembali sebagai default, bukan membuat layar gagal dibuka.
class PrayerPreferences {
  const PrayerPreferences(this._preferences);

  static const _methodKey = 'prayer_method_id';
  static const _madhabKey = 'prayer_asr_madhab';
  static const _adjustmentsKey = 'prayer_adjustments';
  static const _locationKey = 'prayer_location';
  static const _remindersKey = 'prayer_reminders_enabled';
  static const _reminderLeadKey = 'prayer_reminder_lead_minutes';
  static const _reminderKindsKey = 'prayer_reminder_kinds';

  static const int defaultReminderLeadMinutes = 10;

  final AppPreferences _preferences;

  Future<PrayerSettings> load() async {
    final methodId = await _preferences.getInt(_methodKey);
    final madhabName = await _preferences.getString(_madhabKey);
    final adjustmentsRaw = _json(await _preferences.getString(_adjustmentsKey));
    final locationRaw = _json(await _preferences.getString(_locationKey));
    final lead = await _preferences.getInt(_reminderLeadKey);
    final kindsRaw = _json(await _preferences.getString(_reminderKindsKey));

    return PrayerSettings(
      method: _methodOf(methodId),
      asrMadhab: AsrMadhab.fromName(madhabName),
      adjustments: _adjustmentsOf(adjustmentsRaw),
      location: _locationOf(locationRaw),
      remindersEnabled: await _preferences.getBool(_remindersKey) ?? false,
      reminderLeadMinutes: (lead == null || lead < 0)
          ? defaultReminderLeadMinutes
          : lead.clamp(0, PrayerSettings.maxLeadMinutes),
      reminderKinds: _kindsOf(kindsRaw),
    );
  }

  /// Dekode longgar: berkas preferensi yang rusak karena upgrade yang terpotong
  /// harus menghasilkan default, bukan membuat layar waktu sholat gagal dibuka.
  static Object? _json(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(PrayerSettings settings) async {
    await _preferences.setInt(_methodKey, settings.method.aladhanId);
    await _preferences.setString(_madhabKey, settings.asrMadhab.name);
    await _preferences.setString(
      _adjustmentsKey,
      jsonEncode(settings.adjustments.toMap()),
    );
    await _preferences.setBool(_remindersKey, settings.remindersEnabled);
    await _preferences.setInt(
      _reminderLeadKey,
      settings.reminderLeadMinutes,
    );
    await _preferences.setString(
      _reminderKindsKey,
      jsonEncode([for (final kind in settings.reminderKinds) kind.name]),
    );
    final location = settings.location;
    if (location != null) {
      await _preferences.setString(_locationKey, jsonEncode(location.toMap()));
    }
  }

  Future<void> saveLocation(WorshipLocation location) =>
      _preferences.setString(_locationKey, jsonEncode(location.toMap()));

  Future<void> clearLocation() => _preferences.remove(_locationKey);

  static PrayerMethod _methodOf(int? id) {
    if (id == null) return PrayerMethod.defaultMethod;
    for (final method in PrayerMethod.values) {
      if (method.aladhanId == id) return method;
    }
    // Id yang tidak lagi ada di katalog dikembalikan ke bawaan. Mempertahankan
    // id asing berarti menampilkan nama dan sudut yang tidak pernah kita
    // verifikasi dari server, dan dropdown metode tidak punya butir untuknya.
    return PrayerMethod.defaultMethod;
  }

  static PrayerAdjustments _adjustmentsOf(Object? decoded) {
    if (decoded is! Map) return const PrayerAdjustments();
    return PrayerAdjustments.fromMap(decoded.cast<String, dynamic>());
  }

  static WorshipLocation? _locationOf(Object? decoded) {
    if (decoded is! Map) return null;
    final map = decoded.cast<String, dynamic>();
    final name = map['name'];
    final latitude = map['latitude'];
    final longitude = map['longitude'];
    if (name is! String || latitude is! num || longitude is! num) return null;
    final location = WorshipLocation.fromMap(map);
    return WorshipLocation.coordinateInRange(
      location.latitude,
      location.longitude,
    )
    ? location
    : null;
  }

  static Set<PrayerKind> _kindsOf(Object? decoded) {
    if (decoded is! List) return const {};
    return {
      for (final entry in decoded)
        ...PrayerKind.values.where((kind) => kind.name == '$entry' && kind.isSalat),
    };
  }
}
