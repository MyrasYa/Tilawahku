import 'dart:async';

import '../../../core/database/app_database.dart';
import '../../../core/preferences/app_preferences.dart';
import '../domain/prayer_countdown.dart';
import '../domain/prayer_models.dart';
import '../domain/prayer_reminder.dart';
import 'aladhan_prayer_client.dart';
import 'prayer_cache_store.dart';
import 'prayer_preferences.dart';
import 'prayer_reminder_scheduler.dart';

/// Jadwal yang siap tampil beserta keterangan dari mana ia datang.
class PrayerScheduleOutcome {
  const PrayerScheduleOutcome({required this.schedule, this.notice});

  /// Sudah melalui [PrayerDaySchedule.withAdjustments].
  final PrayerDaySchedule schedule;

  /// Diisi bila data datang dari cache karena server gagal dihubungi, atau
  /// bila cache yang dipakai lebih tua dari masa berlakunya.
  final String? notice;
}

class PrayerNeedsLocationException implements Exception {
  const PrayerNeedsLocationException();

  @override
  String toString() => 'Lokasi belum ditentukan.';
}

/// Orkestrasi jadwal salat: jaringan dulu, cache sebagai penyangga, tanpa
/// pernah mengirim permintaan ulang tanpa alasan.
class PrayerRepository {
  PrayerRepository({
    PrayerDaySource? client,
    PrayerCacheStore? cache,
    PrayerPreferences? preferences,
    PrayerReminderScheduler? reminderScheduler,
    DateTime Function()? clock,
  }) : _client = client ?? AladhanPrayerClient(),
       _cache = cache ?? SqlitePrayerCacheStore(AppDatabase.instance),
       _preferences = preferences ?? PrayerPreferences(const AppPreferences()),
       _scheduler = reminderScheduler ?? createPrayerReminderScheduler(),
       _clock = clock ?? DateTime.now;

  /// Jadwal lama dianggap masih layak untuk hari ini selama tidak melebihi ini.
  static const Duration cacheAgeLimit = prayerCacheTtl;

  /// Baris cache yang lebih tua dari ini dibuang saat layar dibuka.
  static const Duration cacheRetention = Duration(days: 400);

  final PrayerDaySource _client;
  final PrayerCacheStore _cache;
  final PrayerPreferences _preferences;
  final PrayerReminderScheduler _scheduler;
  final DateTime Function() _clock;

  /// Permintaan yang sedang berjalan per kunci cache. Pratarik hari berikutnya
  /// dan permintaan layar bisa jatuh pada tanggal yang sama; tanpa peta ini
  /// satu hari diunduh dua kali.
  final Map<String, Future<PrayerScheduleOutcome>> _inFlight = {};

  bool get remindersSupportedByPlatform => _scheduler.supportsPlatform;

  Future<PrayerSettings> loadSettings() => _preferences.load();

  Future<void> saveSettings(PrayerSettings settings) =>
      _preferences.save(settings);

  Future<WorshipLocation> saveLocation(WorshipLocation location) async {
    await _preferences.saveLocation(location);
    return location;
  }

  Future<void> clearLocation() => _preferences.clearLocation();

  /// Ambil jadwal [dateKey].
  ///
  /// Aturan:
  /// * cache yang masih segar dipakai tanpa menyentuh jaringan;
  /// * tanggal selain hari ini selalu dilayani dari cache bila ada (waktu sholat
  ///   adalah hasil hitung, tidak berubah setelah hari itu lewat);
  /// * sisanya minta ke server, lalu simpan ke cache;
  /// * permintaan yang seragam dan sedang berjalan dipakai bersama, bukan diulang;
  /// * server gagal + ada cache = tampilkan cache dengan catatan;
  /// * server gagal + tanpa cache = lempar [PrayerDataSourceException].
  Future<PrayerScheduleOutcome> scheduleFor(
    String dateKey, {
    bool refresh = false,
  }) async {
    final settings = await _preferences.load();
    final location = settings.location;
    if (location == null || !settings.hasValidLocation) {
      throw const PrayerNeedsLocationException();
    }
    final key = scheduleCacheKey(
      dateKey: dateKey,
      location: location,
      method: settings.method,
      asrMadhab: settings.asrMadhab,
    );
    final running = _inFlight[key];
    // [refresh] adalah permintaan eksplisit pengguna, jadi tidak dilayani dari
    // permintaan yang sudah berjalan.
    if (running != null && !refresh) return running;
    // Entri didaftarkan sebelum baca cache supaya pemanggil kedua yang muncul
    // di tengah-tengah proses ikut memakai permintaan yang sama.
    final request = _resolve(
      cacheKey: key,
      dateKey: dateKey,
      location: location,
      settings: settings,
      bypassCache: refresh,
    );
    // Entri lama adalah milik permintaan lain (kasus refresh): pemiliknya yang
    // menghapus, jadi cukup didaftar bila belum ada.
    if (running == null) _inFlight[key] = request;
    try {
      return await request;
    } finally {
      if (_inFlight[key] == request) _inFlight.remove(key);
    }
  }

  Future<PrayerScheduleOutcome> _resolve({
    required String cacheKey,
    required String dateKey,
    required WorshipLocation location,
    required PrayerSettings settings,
    required bool bypassCache,
  }) async {
    final cached = await _cache.load(cacheKey);
    if (cached != null && !bypassCache && _stillUsable(cached, dateKey)) {
      return _ready(cached, settings);
    }
    try {
      final live = await _client.fetchDay(
        dateKey: dateKey,
        location: location,
        method: settings.method,
        asrMadhab: settings.asrMadhab,
      );
      await _cache.save(live, cacheKey: cacheKey);
      if (dateKey == dateKeyFor(_clock(), live.locationOffset)) {
        unawaited(_prefetchNextDay(dateKey));
      }
      return _ready(live, settings);
    } on PrayerDataSourceException catch (error) {
      final fallback = cached;
      if (fallback == null) rethrow;
      // Tanpa labelId enum di sini: "berasal dari dari cache" kalimatnya rusak.
      return PrayerScheduleOutcome(
        schedule: _ready(fallback, settings).schedule,
        notice:
            'Jadwal berasal dari cache karena server tidak dapat dihubungi: '
            '${error.message}',
      );
    }
  }

  /// Sekali saja setelah jadwal hari ini berhasil diunduh: hari berikutnya
  /// ikut disimpan supaya berganti hari tidak butuh jaringan.
  Future<void> _prefetchNextDay(String dateKey) async {
    try {
      await scheduleFor(shiftDateKey(dateKey, 1));
    } on PrayerDataSourceException {
      // Tidak ada jaringan untuk hari berikutnya: hari ini sudah aman.
    }
  }

  bool _stillUsable(PrayerDaySchedule cached, String dateKey) {
    final fetchedAt = cached.fetchedAt;
    if (dateKey != dateKeyFor(_clock(), cached.locationOffset)) return true;
    if (fetchedAt == null) return false;
    return _clock().toUtc().difference(fetchedAt) <= cacheAgeLimit;
  }

  PrayerScheduleOutcome _ready(
    PrayerDaySchedule schedule,
    PrayerSettings settings,
  ) => PrayerScheduleOutcome(
    schedule: schedule.withAdjustments(settings.adjustments),
  );

  /// Menyinkronkan pengingat dengan jadwal yang sedang tampil.
  ///
  /// Mengembalikan `false` bila platform tidak mendukung atau izin ditolak,
  /// supaya layar bisa mengatakan "pengingat tidak aktif" alih-alih berpura-pura.
  Future<bool> syncReminders(
    PrayerDaySchedule schedule,
    PrayerSettings settings,
  ) async {
    if (!settings.remindersEnabled) {
      await _scheduler.clear();
      return false;
    }
    if (!_scheduler.supportsPlatform) return false;
    final prepared = await _scheduler.prepare();
    if (!prepared) return false;
    final plan = PrayerReminderPolicy.plan(
      schedule: schedule,
      kinds: settings.reminderKinds,
      leadMinutes: settings.reminderLeadMinutes,
      now: _clock(),
      locationName: settings.location?.name,
    );
    await _scheduler.sync(plan);
    return plan.isNotEmpty;
  }

  Future<void> clearReminders() => _scheduler.clear();

  Future<void> pruneCache() => _cache.pruneOlderThan(cacheRetention);
}
