import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/prayer/data/aladhan_prayer_client.dart';
import 'package:tilawahku/features/prayer/data/prayer_cache_store.dart';
import 'package:tilawahku/features/prayer/data/prayer_preferences.dart';
import 'package:tilawahku/features/prayer/data/prayer_repository.dart';
import 'package:tilawahku/features/prayer/domain/prayer_method.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';
import 'package:tilawahku/features/prayer/domain/prayer_reminder.dart';

/// Yang diuji di sini adalah kebijakan repositori — kapan jaringan boleh
/// dipanggil, kapan cache dipakai, dan apa yang terjadi saat server gagal —
/// dengan sumber data dan penyimpanannya ditukar, bukan dengan HTTP sungguhan.
void main() {
  const jakarta = WorshipLocation(
    name: 'Jakarta',
    latitude: -6.175,
    longitude: 106.827,
    source: LocationSource.saved,
    timezoneId: 'Asia/Jakarta',
  );
  const today = '2026-11-20';
  // 2026-11-20 02:00 UTC = 09:00 WIB, jadi "hari ini" menurut lokasi.
  final fixedClock = DateTime.utc(2026, 11, 20, 2);

  late _FakeDaySource source;
  late _MemoryCache cache;
  late _FakeScheduler scheduler;
  late PrayerPreferences preferences;
  late PrayerRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = _FakeDaySource();
    cache = _MemoryCache();
    scheduler = _FakeScheduler();
    preferences = PrayerPreferences(const AppPreferences());
    repository = PrayerRepository(
      client: source,
      cache: cache,
      preferences: preferences,
      reminderScheduler: scheduler,
      clock: () => fixedClock,
    );
  });

  Future<void> seed({
    PrayerSettings? settings,
    Map<String, PrayerDaySchedule> cached = const {},
  }) async {
    await preferences.save(
      settings ??
          const PrayerSettings(
            method: PrayerMethod.kemenag,
            asrMadhab: AsrMadhab.standard,
            adjustments: PrayerAdjustments(),
            location: jakarta,
          ),
    );
    for (final entry in cached.entries) {
      await cache.save(entry.value, cacheKey: entry.key);
    }
  }

  String keyFor(
    String dateKey, {
    WorshipLocation location = jakarta,
    PrayerMethod? method,
    AsrMadhab madhab = AsrMadhab.standard,
  }) => scheduleCacheKey(
    dateKey: dateKey,
    location: location,
    method: method ?? PrayerMethod.kemenag,
    asrMadhab: madhab,
  );

  group('jadwal dari jaringan', () {
    test('satu permintaan per kunci, lalu dilayani dari cache', () async {
      await seed();

      final first = await repository.scheduleFor(today);
      await pumpEventQueue();

      expect(first.schedule.source, ScheduleSource.live);
      expect(first.notice, isNull);
      expect(source.calls, 2, reason: 'hari ini + pratarik besok');
      expect(cache.stored.keys, containsAll([keyFor(today), keyFor('2026-11-21')]));

      final second = await repository.scheduleFor(today);
      await pumpEventQueue();
      expect(source.calls, 2, reason: 'cache masih segar, tidak ada permintaan baru');
      expect(second.schedule.source, ScheduleSource.cache);
      expect(second.schedule.eventFor(PrayerKind.fajr)!.wallClock, '04:03');
    });

    test('pratarik hari berikutnya membuat besok tetap bisa dibuka saat luring', () async {
      await seed();
      await repository.scheduleFor(today);
      await pumpEventQueue();
      source.failure = const PrayerDataSourceException(
        PrayerDataFailureKind.offline,
        'Perangkat sedang luring.',
      );

      final tomorrow = await repository.scheduleFor('2026-11-21');
      expect(tomorrow.notice, isNull);
      expect(tomorrow.schedule.dateKey, '2026-11-21');
      expect(source.calls, 2);
    });

    test('refresh memaksa permintaan ulang walau cache masih layak', () async {
      await seed();
      await repository.scheduleFor(today);
      await pumpEventQueue();
      final before = source.calls;

      await repository.scheduleFor(today, refresh: true);
      await pumpEventQueue();
      expect(source.calls, greaterThan(before));
    });

    test('permintaan seragam yang bersamaan turun ke server sekali', () async {
      await seed();

      final outcomes = await Future.wait([
        repository.scheduleFor(today),
        repository.scheduleFor(today),
      ]);
      await pumpEventQueue();

      expect(outcomes.first.schedule.dateKey, today);
      expect(outcomes.last.schedule.dateKey, today);
      expect(source.calls, 2, reason: 'satu unduhan hari ini + satu pratarik');
    });

    test('refresh berdampingan tidak menumpuk permintaan hari berikutnya', () async {
      await seed();

      final outcomes = await Future.wait([
        repository.scheduleFor(today),
        repository.scheduleFor(today, refresh: true),
      ]);
      await pumpEventQueue();

      expect(outcomes, hasLength(2));
      expect(source.lastRequests.where((r) => r.startsWith('2026-11-21|')), hasLength(1),
          reason: 'pratarik dipakai bersama walau dua unduhan hari ini berjalan');
    });
  });

  group('cache sebagai penyangga', () {
    test('server gagal + ada cache: jadwal tetap tampil dengan catatan', () async {
      // Cache basi adalah keadaan yang membuat aplikasi benar-benar mencoba
      // server: kalau masih segar, tidak ada permintaan yang bisa gagal.
      await seed(
        cached: {
          keyFor(today): _schedule(
            today,
            fetchedAt: fixedClock.subtract(
              PrayerRepository.cacheAgeLimit + const Duration(hours: 1),
            ),
          ),
        },
      );
      source.failure = const PrayerDataSourceException(
        PrayerDataFailureKind.timeout,
        'Jadwal sholat tidak dapat diambil tepat waktu.',
      );

      final outcome = await repository.scheduleFor(today);
      expect(outcome.schedule.dateKey, today);
      expect(outcome.notice, contains('cache'));
      expect(outcome.notice, contains('tidak dapat diambil tepat waktu'));
      // Label enum tidak dipakai di kalimat ini: "berasal dari dari cache".
      expect(outcome.notice, isNot(contains('dari dari')));
    });

    test('server gagal + tanpa cache: kegagalan disampaikan, bukan ditutupi', () async {
      await seed();
      source.failure = const PrayerDataSourceException(
        PrayerDataFailureKind.rejected,
        'Layanan jadwal menolak permintaan.',
      );

      await expectLater(
        repository.scheduleFor(today),
        throwsA(isA<PrayerDataSourceException>()),
      );
      expect(cache.stored, isEmpty);
    });

    test('tanggal lampau tidak diminta ulang meskipun cache-nya tua', () async {
      await seed(
        cached: {
          keyFor('2026-11-19'): _schedule(
            '2026-11-19',
            fetchedAt: fixedClock.subtract(const Duration(days: 20)),
          ),
        },
      );

      final outcome = await repository.scheduleFor('2026-11-19');
      expect(source.calls, 0);
      expect(outcome.notice, isNull);
      expect(outcome.schedule.source, ScheduleSource.cache);
    });

    test('cache hari ini yang melewati masa berlaku memicu unduhan ulang', () async {
      await seed(
        cached: {
          keyFor(today): _schedule(
            today,
            fetchedAt: fixedClock.subtract(
              PrayerRepository.cacheAgeLimit + const Duration(minutes: 1),
            ),
          ),
        },
      );

      await repository.scheduleFor(today);
      expect(source.calls, greaterThan(0));
    });

    test('ganti lokasi, metode, atau mazhab memakai kunci lain', () async {
      await seed();
      await repository.scheduleFor(today);
      await pumpEventQueue();
      // Satu untuk hari ini, satu untuk pratarik besok.
      expect(source.calls, 2);

      // Kunci baru belum punya isi untuk hari ini maupun besok, jadi tepat dua
      // permintaan (hari ini + pratarik besok) — tidak lebih.
      Future<void> change(Future<void> Function(PrayerSettings) update) async {
        final before = source.calls;
        final settings = await preferences.load();
        await update(settings);
        await repository.scheduleFor(today);
        await pumpEventQueue();
        expect(source.calls, before + 2, reason: 'satu permintaan per tanggal+kunci');
      }

      await change(
        (settings) => preferences.save(
          settings.copyWith(method: PrayerMethod.byId(3)),
        ),
      );
      expect(source.lastRequests.last, contains('|3|'));

      await change(
        (settings) => preferences.save(
          settings.copyWith(asrMadhab: AsrMadhab.hanafi),
        ),
      );
      expect(source.lastRequests.last, contains('hanafi'));

      await change(
        (settings) => preferences.saveLocation(
          const WorshipLocation(
            name: 'Mekkah',
            latitude: 21.4225,
            longitude: 39.8262,
            source: LocationSource.manual,
          ),
        ),
      );
      expect(source.lastRequests.last, contains('21.422,39.826'));
    });

    test('penyesuaian menit hanya mengubah tampilan, cache tetap nilai server', () async {
      final raw = _schedule(today);
      await seed(
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments({PrayerKind.fajr: -5}),
          location: jakarta,
        ),
        cached: {keyFor(today): raw},
      );

      final outcome = await repository.scheduleFor(today);
      expect(outcome.schedule.eventFor(PrayerKind.fajr)!.wallClock, '03:58');
      expect(outcome.schedule.eventFor(PrayerKind.dhuhr)!.wallClock, '11:38');

      final stored = await cache.load(keyFor(today));
      expect(stored!.eventFor(PrayerKind.fajr)!.wallClock, '04:03');
      expect(source.calls, 0, reason: 'penyesuaian bukan alasan untuk unduh ulang');
    });
  });

  group('lokasi belum ada', () {
    test('diminta sebelum ada permintaan jaringan', () async {
      await seed(
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
        ),
      );

      await expectLater(
        repository.scheduleFor(today),
        throwsA(isA<PrayerNeedsLocationException>()),
      );
      expect(source.calls, 0);
    });

    test('koordinat di luar rentang dianggap belum valid', () async {
      await seed(
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
          location: WorshipLocation(
            name: 'Salah',
            latitude: 120,
            longitude: 0,
            source: LocationSource.manual,
          ),
        ),
      );

      await expectLater(
        repository.scheduleFor(today),
        throwsA(isA<PrayerNeedsLocationException>()),
      );
    });
  });

  group('pengingat', () {
    test('nonaktif berarti membersihkan jadwal lama dan mengembalikan false', () async {
      await seed();
      final armed = await repository.syncReminders(
        _schedule(today),
        (await preferences.load()).copyWith(remindersEnabled: false),
      );
      expect(armed, isFalse);
      expect(scheduler.clears, 1);
      expect(scheduler.lastSync, isNull);
    });

    test('platform tanpa penjadwal tidak berpura-pura menjadwalkan', () async {
      scheduler = _FakeScheduler(supported: false);
      final repo = PrayerRepository(
        client: source,
        cache: cache,
        preferences: preferences,
        reminderScheduler: scheduler,
        clock: () => fixedClock,
      );
      await seed(
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
          location: jakarta,
          remindersEnabled: true,
        ),
      );

      final armed = await repo.syncReminders(
        _schedule(today),
        await preferences.load(),
      );
      expect(armed, isFalse);
      expect(scheduler.lastSync, isNull);
      expect(repo.remindersSupportedByPlatform, isFalse);
    });

    test('izin ditolak tidak dianggap pengingat aktif', () async {
      scheduler = _FakeScheduler(prepareResult: false);
      final repo = PrayerRepository(
        client: source,
        cache: cache,
        preferences: preferences,
        reminderScheduler: scheduler,
        clock: () => fixedClock,
      );
      await seed(
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
          location: jakarta,
          remindersEnabled: true,
        ),
      );

      expect(await repo.syncReminders(_schedule(today), await preferences.load()), isFalse);
      expect(scheduler.lastSync, isNull);
    });

    test('pengingat disinkronkan hanya untuk waktu yang tersisa hari ini', () async {
      await seed(
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
          location: jakarta,
          remindersEnabled: true,
          reminderLeadMinutes: 10,
        ),
      );

      final armed = await repository.syncReminders(
        _schedule(today),
        await preferences.load(),
      );

      expect(armed, isTrue);
      // 09:00 WIB: Subuh sudah lewat, Zuhur sampai Isya masih akan datang.
      expect(scheduler.lastSync!.map((r) => r.kind), [
        PrayerKind.dhuhr,
        PrayerKind.asr,
        PrayerKind.maghrib,
        PrayerKind.isha,
      ]);
      expect(scheduler.lastSync!.first.timezoneId, 'Asia/Jakarta');
    });

    test('semua waktu sudah terlewat berarti tidak ada yang dijadwalkan', () async {
      await seed(
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
          location: jakarta,
          remindersEnabled: true,
        ),
      );
      final lateClock = DateTime.utc(2026, 11, 20, 13); // 20:00 WIB
      final repo = PrayerRepository(
        client: source,
        cache: cache,
        preferences: preferences,
        reminderScheduler: scheduler,
        clock: () => lateClock,
      );

      final armed = await repo.syncReminders(
        _schedule(today),
        await preferences.load(),
      );
      expect(armed, isFalse);
      expect(scheduler.lastSync, isEmpty);
    });
  });

  test('pruneCache memakai masa simpan repositori', () async {
    await repository.pruneCache();
    expect(cache.pruned, [PrayerRepository.cacheRetention]);
  });
}

PrayerDaySchedule _schedule(
  String dateKey, {
  DateTime? fetchedAt,
  PrayerMethod method = PrayerMethod.kemenag,
  AsrMadhab asrMadhab = AsrMadhab.standard,
}) {
  const times = {
    PrayerKind.fajr: '04:03',
    PrayerKind.sunrise: '05:26',
    PrayerKind.dhuhr: '11:38',
    PrayerKind.asr: '15:02',
    PrayerKind.maghrib: '17:51',
    PrayerKind.isha: '19:05',
  };
  return PrayerDaySchedule(
    dateKey: dateKey,
    timezoneId: 'Asia/Jakarta',
    locationOffset: const Duration(hours: 7),
    methodId: method.aladhanId,
    asrMadhab: asrMadhab,
    events: [
      for (final entry in times.entries)
        PrayerEvent(
          kind: entry.key,
          instant: DateTime.parse('${dateKey}T${entry.value}:00+07:00').toUtc(),
          locationOffset: const Duration(hours: 7),
        ),
    ],
    source: ScheduleSource.live,
    fetchedAt: fetchedAt ?? DateTime.utc(2026, 11, 19, 20),
  );
}

class _FakeDaySource implements PrayerDaySource {
  PrayerDataSourceException? failure;
  final lastRequests = <String>[];

  int get calls => lastRequests.length;

  @override
  Future<PrayerDaySchedule> fetchDay({
    required String dateKey,
    required WorshipLocation location,
    required PrayerMethod method,
    required AsrMadhab asrMadhab,
  }) async {
    lastRequests.add(
      '$dateKey|${location.cacheKey}|${method.aladhanId}|${asrMadhab.name}',
    );
    final error = failure;
    if (error != null) throw error;
    return _schedule(dateKey, method: method, asrMadhab: asrMadhab);
  }
}

class _MemoryCache implements PrayerCacheStore {
  final stored = <String, PrayerDaySchedule>{};
  final pruned = <Duration>[];
  final loads = <String>[];

  @override
  Future<void> save(
    PrayerDaySchedule schedule, {
    required String cacheKey,
  }) async {
    stored[cacheKey] = schedule;
  }

  @override
  Future<PrayerDaySchedule?> load(String cacheKey) async {
    loads.add(cacheKey);
    final schedule = stored[cacheKey];
    if (schedule == null) return null;
    return PrayerDaySchedule(
      dateKey: schedule.dateKey,
      timezoneId: schedule.timezoneId,
      locationOffset: schedule.locationOffset,
      methodId: schedule.methodId,
      asrMadhab: schedule.asrMadhab,
      events: schedule.events,
      source: ScheduleSource.cache,
      hijri: schedule.hijri,
      fetchedAt: schedule.fetchedAt,
    );
  }

  @override
  Future<void> pruneOlderThan(Duration age) async => pruned.add(age);
}

class _FakeScheduler implements PrayerReminderScheduler {
  _FakeScheduler({this.supported = true, this.prepareResult = true});

  final bool supported;
  final bool prepareResult;
  int clears = 0;
  List<PrayerReminder>? lastSync;

  @override
  bool get supportsPlatform => supported;

  @override
  Future<bool> prepare() async => prepareResult;

  @override
  Future<void> sync(List<PrayerReminder> reminders) async {
    lastSync = reminders;
  }

  @override
  Future<void> clear() async => clears++;
}
