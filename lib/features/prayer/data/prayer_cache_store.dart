import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/prayer_method.dart';
import '../domain/prayer_models.dart';
import 'aladhan_prayer_client.dart';

/// Penyimpanan cache jadwal sholat.
///
/// Jadwal disimpan per kunci (tanggal + lokasi + metode + madhab) sehingga
/// lokasi atau metode yang berubah tidak pernah membaca cache milik kombinasi
/// lain. Yang disimpan adalah stamp ISO beroffset apa adanya dari layanan,
/// supaya hasil yang tampil bisa ditelusuri ke respons aslinya.
abstract interface class PrayerCacheStore {
  Future<void> save(PrayerDaySchedule schedule, {required String cacheKey});

  Future<PrayerDaySchedule?> load(String cacheKey);

  Future<void> pruneOlderThan(Duration age);
}

class SqlitePrayerCacheStore implements PrayerCacheStore {
  const SqlitePrayerCacheStore(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _database => _appDatabase.database;

  @override
  Future<void> save(
    PrayerDaySchedule schedule, {
    required String cacheKey,
  }) async {
    final db = await _database;
    await db.insert('prayer_schedule_cache', {
      'cache_key': cacheKey,
      'date_key': schedule.dateKey,
      'location_key': _locationKey(cacheKey),
      'method_id': schedule.methodId,
      'asr_madhab': schedule.asrMadhab.name,
      'timezone_id': schedule.timezoneId,
      'offset_minutes': schedule.locationOffset.inMinutes,
      'events_json': jsonEncode(_encodeEvents(schedule)),
      'hijri_json': schedule.hijri == null
          ? null
          : jsonEncode(_encodeHijri(schedule.hijri!)),
      'fetched_at': (schedule.fetchedAt ?? DateTime.now().toUtc())
          .toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<PrayerDaySchedule?> load(String cacheKey) async {
    final db = await _database;
    final rows = await db.query(
      'prayer_schedule_cache',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decode(rows.single);
  }

  @override
  Future<void> pruneOlderThan(Duration age) async {
    final db = await _database;
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    await db.delete(
      'prayer_schedule_cache',
      where: 'fetched_at < ?',
      whereArgs: [cutoff],
    );
  }

  /// Kunci cache mengandung koordinat yang sudah dibulatkan; diambil dari
  /// segmen kedua `tanggal|koordinat|metode|madhab`.
  static String _locationKey(String cacheKey) {
    final parts = cacheKey.split('|');
    return parts.length >= 2 ? parts[1] : cacheKey;
  }

  static List<Map<String, String>> _encodeEvents(PrayerDaySchedule schedule) =>
      [
        for (final event in schedule.events)
          {
            'field': event.kind.apiField,
            'at': _formatIso(event.instant, event.locationOffset),
          },
      ];

  static String _formatIso(DateTime instant, Duration offset) {
    final local = instant.toUtc().add(offset);
    String two(int v) => v.toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    final magnitude = offset.abs();
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
        '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
        '${two(local.second)}$sign${two(magnitude.inHours)}:'
        '${two(magnitude.inMinutes % 60)}';
  }

  static Map<String, dynamic> _encodeHijri(HijriDate hijri) => {
    'day': hijri.day,
    'month': hijri.month,
    'year': hijri.year,
    'month_en': hijri.monthNameEn,
    'month_ar': hijri.monthNameAr,
    'weekday_en': hijri.weekdayEn,
    'method': hijri.method,
    'holidays': hijri.holidays,
  };

  /// Kolom JSON dibaca longgar: baris yang rusak diperlakukan sebagai "tidak
  /// ada cache" supaya layar mengambil ulang, bukan gagal membuka.
  static Object? _json(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static PrayerDaySchedule? _decode(Map<String, Object?> row) {
    final offset = Duration(minutes: (row['offset_minutes'] as num).toInt());
    final timezoneId = row['timezone_id'] as String;
    final events = <PrayerEvent>[];
    final decoded = _json(row['events_json']);
    // Baris tanpa waktu sholat yang bisa dibaca bukan cache yang berguna:
    // kembalikan null agar layar mengambil ulang, bukan menampilkan jadwal kosong.
    if (decoded is! List || decoded.isEmpty) return null;
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final kind = PrayerKind.fromApiField('${entry['field']}');
      final raw = entry['at'];
      if (kind == null || raw is! String) continue;
      final parsed = AladhanPrayerClient.parseInstant(raw);
      if (parsed == null) continue;
      events.add(
        PrayerEvent(kind: kind, instant: parsed.$1, locationOffset: parsed.$2),
      );
    }
    Map<String, dynamic>? hijriMap;
    final decodedHijri = _json(row['hijri_json']);
    if (decodedHijri is Map) {
      hijriMap = decodedHijri.cast<String, dynamic>();
    }
    return PrayerDaySchedule(
      dateKey: row['date_key'] as String,
      timezoneId: timezoneId,
      locationOffset: offset,
      methodId: (row['method_id'] as num).toInt(),
      asrMadhab: AsrMadhab.fromName(row['asr_madhab'] as String?),
      events: events,
      source: ScheduleSource.cache,
      hijri: hijriMap == null ? null : _decodeHijri(hijriMap),
      fetchedAt: DateTime.tryParse('${row['fetched_at']}')?.toUtc(),
    );
  }

  static HijriDate? _decodeHijri(Map<String, dynamic> map) {
    final day = (map['day'] as num?)?.toInt();
    final month = (map['month'] as num?)?.toInt();
    final year = (map['year'] as num?)?.toInt();
    if (day == null || month == null || year == null) return null;
    return HijriDate(
      day: day,
      month: month,
      year: year,
      monthNameEn: '${map['month_en'] ?? ''}',
      monthNameAr: '${map['month_ar'] ?? ''}',
      weekdayEn: '${map['weekday_en'] ?? ''}',
      method: map['method'] == null ? null : '${map['method']}',
      holidays: map['holidays'] is List
          ? (map['holidays'] as List).map((e) => '$e').toList()
          : const [],
    );
  }
}
