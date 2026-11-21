import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/prayer/domain/prayer_method.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';

/// Sudut pada `PrayerMethod.values` tidak boleh dikarang: setiap entri harus
/// cocok dengan `meta.method.params` yang benar-benar dikirim AlAdhan. Fixture
/// `method-params.json` adalah kumpulan respons nyata yang diambil 2026-11-20.
void main() {
  final reported = _methodParams();

  test('setiap metode yang ditawarkan UI punya bukti dari server', () {
    for (final method in PrayerMethod.values) {
      final entry = reported['${method.aladhanId}'];
      expect(
        entry,
        isNotNull,
        reason: 'metode ${method.aladhanId} tanpa bukti',
      );
      expect(
        entry['name'],
        method.name,
        reason: 'nama metode ${method.aladhanId} berbeda dari laporan server',
      );
      final params = entry['params'] as Map<String, dynamic>;
      expect(params['Fajr'], method.fajrAngle);

      final isha = params['Isha'];
      if (isha is num) {
        expect(method.ishaAngle, isha.toDouble());
        expect(method.ishaAfterMaghrib, isNull);
      } else {
        final minutes = int.parse('$isha'.replaceAll(' min', ''));
        expect(method.ishaAfterMaghrib, minutes);
        expect(method.ishaAngle, isNull);
      }
    }
  });

  test('metode bawaan adalah aturan Indonesia dan punya sudutnya sendiri', () {
    expect(PrayerMethod.defaultMethod, PrayerMethod.kemenag);
    expect(PrayerMethod.defaultMethod.aladhanId, 20);
    expect(
      PrayerMethod.defaultMethod.angleSummary,
      'Subuh 20° · Isya sudut 18°',
    );
    expect(PrayerMethod.byId(4).ishaRule, '90 menit setelah Magrib');
    expect(PrayerMethod.byId(5).angleSummary, 'Subuh 19.5° · Isya sudut 17.5°');
  });

  test('byId menolak metode yang tidak ada di katalog', () {
    expect(() => PrayerMethod.byId(999), throwsA(isA<StateError>()));
  });

  test('id metode yang tidak diverifikasi tidak muncul di UI', () {
    final unverified = reported.keys.where(
      (id) => !PrayerMethod.values.any((m) => '${m.aladhanId}' == id),
    );
    expect(unverified, isNotEmpty);
    expect(PrayerMethod.values, hasLength(8));
  });

  group('AsrMadhab', () {
    test('memetakan nilai school yang dipakai API', () {
      expect(AsrMadhab.standard.aladhanSchool, 0);
      expect(AsrMadhab.hanafi.aladhanSchool, 1);
      expect(AsrMadhab.fromName('hanafi'), AsrMadhab.hanafi);
      expect(AsrMadhab.fromName('HANAFI'), AsrMadhab.hanafi);
      expect(AsrMadhab.fromName('standard'), AsrMadhab.standard);
      expect(AsrMadhab.fromName(null), AsrMadhab.standard);
      expect(AsrMadhab.fromName('unknown'), AsrMadhab.standard);
    });

    test('label madhab menyebut madhab yang dikecualikan, bukan satu nama', () {
      expect(AsrMadhab.standard.labelId, contains('Syafi'));
      expect(AsrMadhab.standard.labelId, contains('Hanbali'));
    });
  });

  group('PrayerAdjustments', () {
    test('hanya waktu sholat yang bisa disesuaikan', () {
      const adjustments = PrayerAdjustments();
      expect(
        () => adjustments.set(PrayerKind.sunrise, 5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => const PrayerAdjustments().set(PrayerKind.fajr, 31),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('nilai nol tidak dianggap penyesuaian dan tidak disimpan', () {
      final adjustments = const PrayerAdjustments().set(PrayerKind.fajr, 0);
      expect(adjustments.isEmpty, isTrue);
      expect(adjustments.toMap(), isEmpty);
    });

    test('map tersimpan dipulihkan dan dijepit ke rentang yang aman', () {
      final restored = PrayerAdjustments.fromMap({
        'fajr': -3,
        'isha': 99,
        'sunrise': 5,
        'dhuhr': 0,
        'unknown': 4,
      });
      expect(restored.minutesFor(PrayerKind.fajr), -3);
      expect(
        restored.minutesFor(PrayerKind.isha),
        PrayerAdjustments.maxMinutes,
      );
      expect(restored.minutesFor(PrayerKind.sunrise), isNull);
      expect(restored.minutesFor(PrayerKind.dhuhr), isNull);
      expect(restored.entries, hasLength(2));
    });

    test(
      'penyesuaian menggeser instan dan jam tangan tanpa mengubah sumber',
      () {
        final schedule = _schedule([
          (PrayerKind.fajr, '2026-11-20T04:03:00+07:00'),
          (PrayerKind.dhuhr, '2026-11-20T11:38:00+07:00'),
        ]);
        final adjusted = schedule.withAdjustments(
          const PrayerAdjustments().set(PrayerKind.fajr, -2),
        );
        expect(adjusted.eventFor(PrayerKind.fajr)!.wallClock, '04:01');
        expect(
          adjusted.eventFor(PrayerKind.fajr)!.instant,
          DateTime.utc(2026, 11, 19, 21, 1),
        );
        expect(adjusted.eventFor(PrayerKind.dhuhr)!.wallClock, '11:38');
        expect(adjusted.source, schedule.source);
        expect(adjusted.dateKey, schedule.dateKey);
        // Tanpa penyesuaian, objek dikembalikan apa adanya (bukan salinan).
        expect(
          schedule.withAdjustments(const PrayerAdjustments()),
          same(schedule),
        );
      },
    );
  });

  group('scheduleCacheKey', () {
    test('menggabungkan tanggal, lokasi, metode, dan madhab', () {
      const jakarta = WorshipLocation(
        name: 'Jakarta',
        latitude: -6.1751,
        longitude: 106.8272,
        source: LocationSource.gps,
      );
      String key(
        PrayerMethod method,
        AsrMadhab madhab, {
        WorshipLocation? at,
      }) => scheduleCacheKey(
        dateKey: '2026-11-20',
        location: at ?? jakarta,
        method: method,
        asrMadhab: madhab,
      );

      expect(
        key(PrayerMethod.kemenag, AsrMadhab.standard),
        '2026-11-20|-6.175,106.827|20|standard',
      );
      expect(
        key(PrayerMethod.kemenag, AsrMadhab.standard),
        isNot(key(PrayerMethod.kemenag, AsrMadhab.hanafi)),
      );
      expect(
        key(PrayerMethod.kemenag, AsrMadhab.standard),
        isNot(key(PrayerMethod.byId(3), AsrMadhab.standard)),
      );
      expect(
        key(
          PrayerMethod.kemenag,
          AsrMadhab.standard,
          at: const WorshipLocation(
            name: 'Bandung',
            latitude: -6.9,
            longitude: 107.6,
            source: LocationSource.gps,
          ),
        ),
        isNot(key(PrayerMethod.kemenag, AsrMadhab.standard)),
      );
    });

    test(
      'koordinat dibulatkan sehingga getaran GPS tidak membuat kunci baru',
      () {
        const a = WorshipLocation(
          name: 'Jakarta',
          latitude: -6.1754,
          longitude: 106.8271,
          source: LocationSource.gps,
        );
        const b = WorshipLocation(
          name: 'Jakarta',
          latitude: -6.1752,
          longitude: 106.8273,
          source: LocationSource.gps,
        );
        expect(a.cacheKey, b.cacheKey);
      },
    );
  });

  group('WorshipLocation', () {
    test('petanya ke pref dan kembali tanpa kehilangan asal lokasi', () {
      const location = WorshipLocation(
        name: 'Jakarta',
        latitude: -6.175,
        longitude: 106.827,
        source: LocationSource.saved,
        timezoneId: 'Asia/Jakarta',
        country: 'ID',
      );
      final restored = WorshipLocation.fromMap(location.toMap());
      expect(restored.name, 'Jakarta');
      expect(restored.latitude, -6.175);
      expect(restored.longitude, 106.827);
      expect(restored.source, LocationSource.saved);
      expect(restored.timezoneId, 'Asia/Jakarta');
      expect(restored.country, 'ID');
    });

    test('koordinat di luar rentang ditolak sebelum permintaan jaringan', () {
      expect(WorshipLocation.coordinateInRange(-6.175, 106.827), isTrue);
      expect(WorshipLocation.coordinateInRange(91, 0), isFalse);
      expect(WorshipLocation.coordinateInRange(0, 181), isFalse);
      expect(WorshipLocation.coordinateInRange(-90, 180), isTrue);
    });
  });
}

Map<String, dynamic> _methodParams() {
  final file = File('test/fixtures/aladhan/method-params.json');
  if (!file.existsSync()) {
    throw StateError('Fixture hilang: ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

PrayerDaySchedule _schedule(List<(PrayerKind, String)> raw) =>
    PrayerDaySchedule(
      dateKey: '2026-11-20',
      timezoneId: 'Asia/Jakarta',
      locationOffset: const Duration(hours: 7),
      methodId: 20,
      asrMadhab: AsrMadhab.standard,
      events: [
        for (final (kind, stamp) in raw)
          PrayerEvent(
            kind: kind,
            instant: DateTime.parse(stamp).toUtc(),
            locationOffset: const Duration(hours: 7),
          ),
      ],
      source: ScheduleSource.live,
    );
