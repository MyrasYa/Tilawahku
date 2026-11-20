import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/aladhan_prayer_client.dart';
import '../data/city_location_catalog.dart';
import '../data/device_location.dart';
import '../data/prayer_repository.dart';
import '../domain/prayer_countdown.dart';
import '../domain/prayer_method.dart';
import '../domain/prayer_models.dart';

enum PrayerLoadState { loading, ready, needsLocation, failed }

/// State layar waktu salat: jadwal, hitung mundur, dan seluruh perubahan
/// preferensi. Widget hanya membaca properti dan memanggil aksi.
class PrayerTimesController extends ChangeNotifier {
  PrayerTimesController({
    PrayerRepository? repository,
    DeviceLocationProvider? deviceLocation,
    CityLocationCatalog? cityCatalog,
    DateTime Function()? clock,
  }) : _repository = repository ?? PrayerRepository(),
       _deviceLocation = deviceLocation ?? const GeolocatorDeviceLocation(),
       _cities = cityCatalog ?? CityLocationCatalog(),
       _clock = clock ?? DateTime.now;

  final PrayerRepository _repository;
  final DeviceLocationProvider _deviceLocation;
  final CityLocationCatalog _cities;
  final DateTime Function() _clock;

  PrayerLoadState state = PrayerLoadState.loading;
  PrayerSettings settings = const PrayerSettings(
    method: PrayerMethod.defaultMethod,
    asrMadhab: AsrMadhab.standard,
    adjustments: PrayerAdjustments(),
  );
  List<WorshipLocation> cities = const [];

  /// 0 = hari ini, -1 kemarin, +1 besok, dst.
  int dayOffset = 0;

  /// Jadwal siap tampil (sudah termasuk penyesuaian manual).
  PrayerDaySchedule? schedule;
  PrayerDaySchedule? followingSchedule;
  String? notice;
  String? errorMessage;
  String? locationMessage;

  bool busy = false;
  bool remindersArmed = false;

  PrayerDaySchedule? _rawSchedule;
  PrayerDaySchedule? _rawFollowing;
  Timer? _ticker;
  int _generation = 0;

  bool get remindersSupportedByPlatform =>
      _repository.remindersSupportedByPlatform;

  bool get isToday => dayOffset == 0;

  DateTime get now => _clock();

  /// Zona waktu lokasi menentukan "tanggal lokasi"; sebelum jadwal pertama
  /// tiba, tanggal perangkat dipakai sebagai perkiraan.
  Duration get _dayHintOffset =>
      schedule?.locationOffset ?? _clock().timeZoneOffset;

  String get viewedDateKey =>
      shiftDateKey(dateKeyFor(_clock(), _dayHintOffset), dayOffset);

  List<PrayerEvent> get windowEvents => [
    for (final day in [schedule, followingSchedule])
      if (day != null) ...day.salatEvents,
  ];

  UpcomingPrayer? get upcoming => nextSalatEvent(windowEvents, _clock());

  PrayerEvent? get currentSalat => currentSalatEvent(windowEvents, _clock());

  String get countdownLabel {
    final next = upcoming;
    return next == null ? '--:--:--' : formatCountdown(next.remaining);
  }

  Future<void> start() async {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    try {
      cities = await _cities.load();
    } on Object {
      cities = const [];
    }
    settings = await _repository.loadSettings();
    unawaited(_repository.pruneCache());
    if (settings.location == null) {
      state = PrayerLoadState.needsLocation;
      notifyListeners();
      return;
    }
    await _load();
  }

  Future<void> refresh() => _load(refresh: true);

  Future<void> previousDay() async {
    dayOffset -= 1;
    await _load();
  }

  Future<void> nextDay() async {
    dayOffset += 1;
    await _load();
  }

  Future<void> backToToday() async {
    dayOffset = 0;
    await _load();
  }

  Future<void> useDeviceLocation() async {
    busy = true;
    locationMessage = null;
    notifyListeners();
    try {
      final location = await _deviceLocation.locate();
      await _applyLocation(location);
    } on LocationFailure catch (failure) {
      locationMessage = '${failure.message} ${failure.suggestion}';
    } on Object catch (error) {
      locationMessage = 'Lokasi gagal diambil: $error';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> selectCity(WorshipLocation city) => _applyLocation(
    WorshipLocation(
      name: city.name,
      latitude: city.latitude,
      longitude: city.longitude,
      source: LocationSource.saved,
      timezoneId: city.timezoneId,
      country: city.country,
    ),
  );

  Future<void> enterCoordinates({
    required String name,
    required double latitude,
    required double longitude,
  }) {
    if (!WorshipLocation.coordinateInRange(latitude, longitude)) {
      locationMessage = 'Koordinat harus dalam rentang -90..90 dan -180..180.';
      notifyListeners();
      return Future.value();
    }
    locationMessage = null;
    return _applyLocation(
      WorshipLocation(
        name: name.trim().isEmpty ? 'Lokasi manual' : name.trim(),
        latitude: latitude,
        longitude: longitude,
        source: LocationSource.manual,
      ),
    );
  }

  Future<void> _applyLocation(WorshipLocation location) async {
    settings = settings.copyWith(location: location);
    await _repository.saveLocation(location);
    dayOffset = 0;
    _rawFollowing = null;
    followingSchedule = null;
    await _load(refresh: true);
  }

  Future<void> selectMethod(PrayerMethod value) =>
      _updateSettings(settings.copyWith(method: value));

  Future<void> selectMadhab(AsrMadhab value) =>
      _updateSettings(settings.copyWith(asrMadhab: value));

  Future<void> setAdjustment(PrayerKind kind, int minutes) => _updateSettings(
    settings.copyWith(adjustments: settings.adjustments.set(kind, minutes)),
  );

  Future<void> setRemindersEnabled(bool enabled) => _updateSettings(
    settings.copyWith(remindersEnabled: enabled),
    rescheduleReminders: true,
  );

  Future<void> setReminderLead(int minutes) => _updateSettings(
    settings.copyWith(reminderLeadMinutes: minutes),
    rescheduleReminders: true,
  );

  Future<void> toggleReminderKind(PrayerKind kind) {
    final kinds = {...settings.reminderKinds};
    if (!kinds.remove(kind)) kinds.add(kind);
    return _updateSettings(
      settings.copyWith(reminderKinds: kinds),
      rescheduleReminders: true,
    );
  }

  Future<void> _updateSettings(
    PrayerSettings next, {
    bool rescheduleReminders = false,
  }) async {
    final needsReload =
        next.location?.cacheKey != settings.location?.cacheKey ||
        next.method.aladhanId != settings.method.aladhanId ||
        next.asrMadhab != settings.asrMadhab;
    settings = next;
    await _repository.saveSettings(next);
    if (needsReload) {
      // Kunci cache mengandung lokasi, metode, dan madhab: kombinasi baru bisa
      // saja sudah tercache, jadi tidak selalu berarti permintaan jaringan.
      _rawFollowing = null;
      followingSchedule = null;
      await _load();
      return;
    }
    _rawSchedule ??= schedule;
    schedule = _rawSchedule?.withAdjustments(next.adjustments);
    followingSchedule = _rawFollowing?.withAdjustments(next.adjustments);
    if (rescheduleReminders) await _syncReminders();
    notifyListeners();
  }

  Future<void> _load({bool refresh = false}) async {
    final generation = ++_generation;
    final location = settings.location;
    if (location == null) {
      state = PrayerLoadState.needsLocation;
      notifyListeners();
      return;
    }
    busy = true;
    errorMessage = null;
    if (state != PrayerLoadState.ready) state = PrayerLoadState.loading;
    notifyListeners();
    final dateKey = viewedDateKey;
    try {
      final outcome = await _repository.scheduleFor(
        dateKey,
        refresh: refresh,
      );
      if (generation != _generation) return;
      _rawSchedule = outcome.schedule;
      schedule = outcome.schedule.withAdjustments(settings.adjustments);
      notice = outcome.notice;
      state = PrayerLoadState.ready;
      if (dayOffset == 0 &&
          needsFollowingDay(outcome.schedule.salatEvents, _clock())) {
        final following = await _repository.scheduleFor(
          shiftDateKey(outcome.schedule.dateKey, 1),
        );
        if (generation != _generation) return;
        _rawFollowing = following.schedule;
        followingSchedule = following.schedule.withAdjustments(
          settings.adjustments,
        );
      } else {
        _rawFollowing = null;
        followingSchedule = null;
      }
      await _syncReminders();
    } on PrayerNeedsLocationException {
      if (generation != _generation) return;
      state = PrayerLoadState.needsLocation;
    } on PrayerDataSourceException catch (error) {
      if (generation != _generation) return;
      state = PrayerLoadState.failed;
      errorMessage = error.message;
      notice = null;
    } on Object catch (error) {
      if (generation != _generation) return;
      state = PrayerLoadState.failed;
      errorMessage = 'Jadwal tidak dapat dimuat: $error';
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _syncReminders() async {
    final current = schedule;
    if (current == null) return;
    try {
      remindersArmed = await _repository.syncReminders(current, settings);
    } on Object {
      remindersArmed = false;
    }
  }

  void _tick() {
    final current = _rawSchedule;
    if (state != PrayerLoadState.ready || current == null) return;
    if (dayOffset == 0 && dateKeyFor(_clock(), current.locationOffset) != current.dateKey) {
      // Hari lokasi berganti (mis. setelah Isya): muat jadwal hari baru agar
      // hitung mundur menuju Subuh, bukan berhenti.
      _rawFollowing = null;
      followingSchedule = null;
      unawaited(_load());
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
