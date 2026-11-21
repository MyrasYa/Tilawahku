import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../prayer/data/aladhan_prayer_client.dart';
import '../../prayer/data/prayer_repository.dart';
import '../../prayer/domain/prayer_models.dart';
import '../data/hijri_calendar_repository.dart';
import '../domain/hijri_models.dart';

enum HijriLoadState { loading, ready, needsLocation, failed }

/// Controller untuk layar Kalender Hijri.
class HijriCalendarController extends ChangeNotifier {
  HijriCalendarController({
    HijriCalendarRepository? repository,
    PrayerRepository? prayerRepository,
    DateTime Function()? clock,
  }) : _repository = repository ?? HijriCalendarRepository(),
       _prayerRepository = prayerRepository ?? PrayerRepository(),
       _clock = clock ?? DateTime.now,
       _gregorianYear = (clock ?? DateTime.now)().year,
       _gregorianMonth = (clock ?? DateTime.now)().month {
    _initFuture = _initialize();
    _load();
  }

  final HijriCalendarRepository _repository;
  final PrayerRepository _prayerRepository;
  final DateTime Function() _clock;
  late final Future<void> _initFuture;

  HijriLoadState state = HijriLoadState.loading;
  HijriCalendarMonth? month;
  HijriCalendarDay? selectedDay;
  String? notice;
  String? errorMessage;
  bool busy = false;

  int _gregorianYear;
  int _gregorianMonth;
  int _generation = 0;

  int get gregorianYear => _gregorianYear;
  int get gregorianMonth => _gregorianMonth;

  WorshipLocation? _location;

  /// Lokasi yang dipakai (diambil dari pengaturan sholat).
  WorshipLocation? get location => _location;

  DateTime get now => _clock();

  /// Penyesuaian Hijri saat ini.
  HijriAdjustment get adjustment => _repository.adjustment;

  /// Penyesuaian aktif?
  bool get hasAdjustment => adjustment.isActive;

  /// Label penyesuaian.
  String get adjustmentLabel {
    final days = adjustment.days;
    if (days == 0) return 'Tidak ada penyesuaian';
    return 'Penyesuaian: ${days > 0 ? '+$days' : '$days'} hari';
  }

  Future<void> _initialize() async {
    try {
      await _repository.loadAdjustment();
      final settings = await _prayerRepository.loadSettings();
      _location = settings.location;
    } on Object {
      // Gunakan default jika gagal
    }
  }

  Future<void> _load({bool refresh = false}) async {
    final generation = ++_generation;
    busy = true;
    errorMessage = null;
    if (state != HijriLoadState.ready) state = HijriLoadState.loading;
    notifyListeners();

    await _initFuture;
    if (generation != _generation) return;

    final place = location;
    if (place == null) {
      state = HijriLoadState.needsLocation;
      busy = false;
      notifyListeners();
      return;
    }

    try {
      final outcome = await _repository.monthFor(
        gregorianYear: _gregorianYear,
        gregorianMonth: _gregorianMonth,
        location: place,
        refresh: refresh,
      );
      if (generation != _generation) return;

      month = outcome.month;
      notice = outcome.notice;
      state = HijriLoadState.ready;

      // Pilih hari ini sebagai default apabila belum ada pilihan
      if (month?.currentHijriDate != null && selectedDay == null) {
        selectedDay = month!.currentHijriDate;
      }
    } on HijriNeedsLocationException {
      if (generation != _generation) return;
      state = HijriLoadState.needsLocation;
    } on Object catch (error) {
      if (generation != _generation) return;
      if (error is PrayerDataSourceException) {
        state = HijriLoadState.failed;
        errorMessage = error.message;
        notice = null;
      } else {
        state = HijriLoadState.failed;
        errorMessage = 'Kalender tidak dapat dimuat: $error';
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Navigasi ke bulan sebelumnya.
  Future<void> previousMonth() async {
    _gregorianMonth--;
    if (_gregorianMonth < 1) {
      _gregorianMonth = 12;
      _gregorianYear--;
    }
    selectedDay = null;
    await _load();
  }

  /// Navigasi ke bulan berikutnya.
  Future<void> nextMonth() async {
    _gregorianMonth++;
    if (_gregorianMonth > 12) {
      _gregorianMonth = 1;
      _gregorianYear++;
    }
    selectedDay = null;
    await _load();
  }

  /// Pilih tanggal.
  void selectDay(HijriCalendarDay day) {
    selectedDay = day;
    notifyListeners();
  }

  /// Set penyesuaian Hijri.
  Future<void> setAdjustment(int days) async {
    final adjustment = HijriAdjustment(days).validated();
    await _repository.setAdjustment(adjustment);
    notifyListeners();

    // Reload kalender dengan penyesuaian baru
    await _load(refresh: false);
  }

  /// Refresh kalender dari server.
  Future<void> refresh() async {
    if (busy) return;
    await _load(refresh: true);
  }

  /// Buka pengaturan lokasi sholat.
  Future<void> openLocationSettings() async {
    // UI akan menangani navigasi ke layar sholat
    // Controller hanya menyediakan aksi
  }
}
