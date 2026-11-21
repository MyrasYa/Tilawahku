import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../prayer/data/aladhan_prayer_client.dart';
import '../../prayer/domain/prayer_models.dart';
import 'hijri_calendar_source.dart';
import '../domain/hijri_models.dart';

/// Hasil pengambilan kalender bulanan.
class HijriCalendarOutcome {
  const HijriCalendarOutcome({required this.month, this.notice});

  final HijriCalendarMonth month;
  final String? notice;
}

/// Repository untuk kalender Hijri dengan caching.
class HijriCalendarRepository {
  HijriCalendarRepository({
    AppDatabase? appDatabase,
    HijriCalendarSource? calendarSource,
    HijriAdjustment? initialAdjustment,
  }) : _appDatabase = appDatabase ?? AppDatabase.instance,
       _calendarSource = calendarSource ?? AladhanHijriCalendarSource(),
       _adjustment = initialAdjustment ?? const HijriAdjustment();

  final AppDatabase _appDatabase;
  final HijriCalendarSource _calendarSource;
  HijriAdjustment _adjustment;

  /// Kunci cache untuk kalender bulanan.
  static String cacheKey({
    required int gregorianYear,
    required int gregorianMonth,
    required WorshipLocation location,
  }) => '$gregorianYear-$gregorianMonth|${location.cacheKey}';

  /// Penyesuaian Hijri saat ini.
  HijriAdjustment get adjustment => _adjustment;

  /// Simpan penyesuaian Hijri.
  Future<void> setAdjustment(HijriAdjustment adjustment) async {
    _adjustment = adjustment.validated();
    await _saveAdjustment();
  }

  /// Ambil kalender bulanan dengan caching.
  Future<HijriCalendarOutcome> monthFor({
    required int gregorianYear,
    required int gregorianMonth,
    WorshipLocation? location,
    bool refresh = false,
  }) async {
    final place = location;
    if (place == null) {
      throw const HijriNeedsLocationException();
    }

    final key = cacheKey(
      gregorianYear: gregorianYear,
      gregorianMonth: gregorianMonth,
      location: place,
    );

    if (!refresh) {
      final cached = await _loadCache(key);
      if (cached != null) {
        return HijriCalendarOutcome(
          month: cached.withAdjustment(_adjustment.days),
          notice: 'dari cache',
        );
      }
    }

    try {
      final month = await _calendarSource.fetchMonth(
        gregorianYear: gregorianYear,
        gregorianMonth: gregorianMonth,
        location: place,
      );
      await _saveCache(key, month);
      return HijriCalendarOutcome(
        month: month.withAdjustment(_adjustment.days),
      );
    } on PrayerDataSourceException catch (error) {
      // Fallback ke cache jika ada
      final cached = await _loadCache(key);
      if (cached != null) {
        return HijriCalendarOutcome(
          month: cached.withAdjustment(_adjustment.days),
          notice: 'dari cache (${error.message})',
        );
      }
      rethrow;
    }
  }

  /// Simpan kalender ke cache.
  Future<void> _saveCache(String key, HijriCalendarMonth month) async {
    final db = await _appDatabase.database;
    final json = _encodeMonth(month);
    await db.insert('hijri_calendar_cache', {
      'cache_key': key,
      'gregorian_year': month.gregorianYear,
      'gregorian_month': month.gregorianMonth,
      'month_json': json,
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Baca kalender dari cache.
  Future<HijriCalendarMonth?> _loadCache(String key) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'hijri_calendar_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeMonth(rows.single);
  }

  /// Simpan penyesuaian ke SharedPreferences.
  Future<void> _saveAdjustment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hijri_adjustment', jsonEncode(_adjustment.toMap()));
  }

  /// Baca penyesuaian dari SharedPreferences (public untuk initialization).
  Future<void> loadAdjustment() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hijri_adjustment');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _adjustment = HijriAdjustment.fromMap(map);
      } on Object {
        // Gunakan default jika gagal membaca
        _adjustment = const HijriAdjustment();
      }
    }
  }

  /// Encode bulan kalender ke JSON.
  static String _encodeMonth(HijriCalendarMonth month) {
    final daysJson = [
      for (final day in month.days)
        {
          'gregorian_date': day.gregorianDate,
          'hijri_day': day.hijriDay,
          'hijri_month': day.hijriMonth,
          'hijri_year': day.hijriYear,
          'hijri_month_name_en': day.hijriMonthNameEn,
          'hijri_month_name_ar': day.hijriMonthNameAr,
          'hijri_month_name_id': day.hijriMonthNameId,
          'weekday_en': day.weekdayEn,
          'weekday_ar': day.weekdayAr,
          'is_today': day.isToday,
          'events': day.events
              .map(
                (e) => {
                  'hijri_day': e.hijriDay,
                  'hijri_month': e.hijriMonth,
                  'name_id': e.nameId,
                  'description': e.description,
                },
              )
              .toList(),
        },
    ];
    return jsonEncode({
      'gregorian_year': month.gregorianYear,
      'gregorian_month': month.gregorianMonth,
      'days': daysJson,
    });
  }

  /// Decode bulan kalender dari JSON.
  static HijriCalendarMonth _decodeMonth(Map<String, dynamic> row) {
    final json =
        jsonDecode(row['month_json'] as String) as Map<String, dynamic>;
    final daysJson = json['days'] as List;
    final days = [
      for (final dayJson in daysJson)
        HijriCalendarDay(
          gregorianDate: dayJson['gregorian_date'] as String,
          hijriDay: dayJson['hijri_day'] as int,
          hijriMonth: dayJson['hijri_month'] as int,
          hijriYear: dayJson['hijri_year'] as int,
          hijriMonthNameEn: dayJson['hijri_month_name_en'] as String,
          hijriMonthNameAr: dayJson['hijri_month_name_ar'] as String,
          hijriMonthNameId: dayJson['hijri_month_name_id'] as String,
          weekdayEn: dayJson['weekday_en'] as String,
          weekdayAr: dayJson['weekday_ar'] as String,
          isToday: dayJson['is_today'] as bool,
          events: (dayJson['events'] as List).map((e) {
            final event = e as Map<String, dynamic>;
            return IslamicEvent(
              hijriDay: event['hijri_day'] as int,
              hijriMonth: event['hijri_month'] as int,
              nameId: event['name_id'] as String,
              description: event['description'] as String,
            );
          }).toList(),
        ),
    ];

    // Cari hari ini
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    HijriCalendarDay? currentHijriDate;
    for (final day in days) {
      if (day.gregorianDate == dateKey) {
        currentHijriDate = day;
        break;
      }
    }

    return HijriCalendarMonth(
      gregorianYear: json['gregorian_year'] as int,
      gregorianMonth: json['gregorian_month'] as int,
      days: days,
      currentHijriDate: currentHijriDate,
    );
  }

  /// Bersihkan cache lama.
  Future<void> pruneOlderThan(Duration age) async {
    final db = await _appDatabase.database;
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    await db.delete(
      'hijri_calendar_cache',
      where: 'cached_at < ?',
      whereArgs: [cutoff],
    );
  }
}

/// Kalender Hijri membutuhkan lokasi.
class HijriNeedsLocationException implements Exception {
  const HijriNeedsLocationException();
  @override
  String toString() => 'Kalender Hijri membutuhkan lokasi.';
}
