import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/prayer/domain/prayer_countdown.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';

/// Waktu sholat Jakarta 2026-11-20 dan 2026-11-21 seperti yang dilaporkan
/// AlAdhan untuk metode 20 (Kemenag): 04:03 / 05:26 / 11:38 / 15:02 / 17:51 /
/// 19:05 pada zona +07:00.
const _offset = Duration(hours: 7);

void main() {
  final today = _day('2026-11-20');
  final tomorrow = _day('2026-11-21');

  group('sortedSalatEvents', () {
    test('membuang Syuruk dan mengurutkan berdasarkan instan', () {
      final shuffled = [
        today[4],
        today[0],
        today[1],
        today[3],
        today[2],
        today[5],
      ];
      final sorted = sortedSalatEvents(shuffled);
      expect(sorted.map((event) => event.kind), [
        PrayerKind.fajr,
        PrayerKind.dhuhr,
        PrayerKind.asr,
        PrayerKind.maghrib,
        PrayerKind.isha,
      ]);
    });
  });

  group('nextSalatEvent', () {
    test('sebelum Subuh menghitung dari jam lokasi, bukan jam perangkat', () {
      // 2026-11-19 21:00 UTC = 2026-11-20 04:00 WIB: 3 menit sebelum Subuh.
      final upcoming = nextSalatEvent(
        today,
        DateTime.utc(2026, 11, 19, 21, 0),
      )!;
      expect(upcoming.kind, PrayerKind.fajr);
      expect(upcoming.remaining, const Duration(minutes: 3));
      expect(upcoming.previous, isNull);
    });

    test(
      'di tengah hari menyebut sholat berikutnya dan yang sedang berjalan',
      () {
        // 2026-11-20 09:00 UTC = 16:00 WIB: Asar sudah lewat, Magrib berikutnya.
        final upcoming = nextSalatEvent(today, DateTime.utc(2026, 11, 20, 9))!;
        expect(upcoming.kind, PrayerKind.maghrib);
        expect(upcoming.previous?.kind, PrayerKind.asr);
        expect(upcoming.remaining, const Duration(hours: 1, minutes: 51));
      },
    );

    test('tepat pada waktu sholat tidak lagi dihitung sebagai mendatang', () {
      final upcoming = nextSalatEvent(
        today,
        DateTime.utc(2026, 11, 20, 4, 38),
      )!;
      expect(upcoming.kind, PrayerKind.asr);
    });

    test(
      'setelah Isya hari ini butuh hari berikutnya agar hitung mundur tetap ada',
      () {
        final lateNight = DateTime.utc(2026, 11, 20, 13); // 20:00 WIB
        expect(nextSalatEvent(today, lateNight), isNull);
        expect(needsFollowingDay(today, lateNight), isTrue);

        final combined = [...today, ...tomorrow];
        final upcoming = nextSalatEvent(combined, lateNight)!;
        expect(upcoming.kind, PrayerKind.fajr);
        expect(upcoming.event.instant, DateTime.utc(2026, 11, 20, 21, 3));
        expect(upcoming.previous?.kind, PrayerKind.isha);
        expect(upcoming.remaining, const Duration(hours: 8, minutes: 3));
        expect(needsFollowingDay(combined, lateNight), isFalse);
      },
    );

    test('sebelum semua kejadian yang dikenal tidak ada jendela berjalan', () {
      final early = DateTime.utc(2026, 11, 19, 20); // 03:00 WIB
      expect(currentSalatEvent(today, early), isNull);
      expect(nextSalatEvent(today, early)!.kind, PrayerKind.fajr);
    });

    test('yang sedang berjalan adalah kejadian terakhir yang sudah lewat', () {
      expect(
        // 18:00 WIB: setelah Magrib, sebelum Isya.
        currentSalatEvent(today, DateTime.utc(2026, 11, 20, 11))!.kind,
        PrayerKind.maghrib,
      );
      expect(
        // 05:00 WIB keesokan hari, namun daftar hanya berisi hari ini.
        currentSalatEvent(today, DateTime.utc(2026, 11, 20, 22))!.kind,
        PrayerKind.isha,
      );
    });
  });

  group('dateKeyFor', () {
    test('memakai tanggal lokasi, bukan tanggal perangkat', () {
      // 2026-11-20 17:30 UTC: masih 20-Nov di UTC, sudah 21-Nov di WIB.
      expect(
        dateKeyFor(DateTime.utc(2026, 11, 20, 17, 30), _offset),
        '2026-11-21',
      );
      expect(
        dateKeyFor(DateTime.utc(2026, 11, 20, 17, 30), Duration.zero),
        '2026-11-20',
      );
      // 2026-11-19 17:00 UTC tepat tengah malam WIB.
      expect(dateKeyFor(DateTime.utc(2026, 11, 19, 17), _offset), '2026-11-20');
      expect(
        dateKeyFor(DateTime.utc(2026, 11, 20, 16, 59), _offset),
        '2026-11-20',
      );
    });

    test('offset negatif juga benar', () {
      expect(
        dateKeyFor(DateTime.utc(2026, 11, 20, 2), const Duration(hours: -5)),
        '2026-11-19',
      );
    });
  });

  group('shiftDateKey', () {
    test('menyeberang batas bulan dan tahun', () {
      expect(shiftDateKey('2026-11-20', 1), '2026-11-21');
      expect(shiftDateKey('2026-11-20', -1), '2026-11-19');
      expect(shiftDateKey('2026-11-30', 1), '2026-12-01');
      expect(shiftDateKey('2026-12-31', 1), '2027-01-01');
      expect(shiftDateKey('2027-01-01', -1), '2026-12-31');
    });

    test('menghormati tahun kabisat', () {
      expect(shiftDateKey('2028-02-28', 1), '2028-02-29');
      expect(shiftDateKey('2026-02-28', 1), '2026-03-01');
    });

    test('menolak kunci yang tidak lengkap', () {
      expect(() => shiftDateKey('2026-11', 1), throwsA(isA<FormatException>()));
    });
  });

  group('format', () {
    test('hitung mundur selalu jam:menit:detik dan tidak pernah negatif', () {
      expect(
        formatCountdown(const Duration(hours: 2, minutes: 3, seconds: 4)),
        '02:03:04',
      );
      expect(formatCountdown(const Duration(seconds: 45)), '00:00:45');
      expect(formatCountdown(const Duration(days: 1)), '24:00:00');
      expect(formatCountdown(const Duration(seconds: -30)), '00:00:00');
      expect(formatCountdown(Duration.zero), '00:00:00');
    });

    test('durasi ringkas tidak pernah negatif', () {
      expect(formatDurationShort(const Duration(minutes: 45)), '45 menit');
      expect(
        formatDurationShort(const Duration(minutes: 90)),
        '1 jam 30 menit',
      );
      expect(formatDurationShort(const Duration(minutes: 120)), '2 jam');
      expect(formatDurationShort(const Duration(seconds: -10)), '0 menit');
    });
  });
}

List<PrayerEvent> _day(String dateKey) {
  const wallClocks = {
    PrayerKind.fajr: '04:03',
    PrayerKind.sunrise: '05:26',
    PrayerKind.dhuhr: '11:38',
    PrayerKind.asr: '15:02',
    PrayerKind.maghrib: '17:51',
    PrayerKind.isha: '19:05',
  };
  return [
    for (final entry in wallClocks.entries)
      PrayerEvent(
        kind: entry.key,
        instant: DateTime.parse('${dateKey}T${entry.value}:00+07:00').toUtc(),
        locationOffset: _offset,
      ),
  ];
}
