import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/prayer/data/aladhan_prayer_client.dart';
import 'package:tilawahku/features/prayer/data/city_location_catalog.dart';
import 'package:tilawahku/features/prayer/data/device_location.dart';
import 'package:tilawahku/features/prayer/data/prayer_cache_store.dart';
import 'package:tilawahku/features/prayer/data/prayer_preferences.dart';
import 'package:tilawahku/features/prayer/data/prayer_repository.dart';
import 'package:tilawahku/features/prayer/domain/prayer_method.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';
import 'package:tilawahku/features/prayer/domain/prayer_reminder.dart';
import 'package:tilawahku/features/prayer/presentation/prayer_times_controller.dart';
import 'package:tilawahku/features/prayer/presentation/prayer_times_screen.dart';

/// Layar diuji dengan sumber data dan penyimpanan tiruan: yang diperiksa adalah
/// apa yang dilihat pengguna (jadwal, hitung mundur, keadaan luring) dan apakah
/// aksi widget benar-benar lewat controller.
void main() {
  const jakarta = WorshipLocation(
    name: 'Jakarta',
    latitude: -6.175,
    longitude: 106.827,
    source: LocationSource.saved,
    timezoneId: 'Asia/Jakarta',
    country: 'ID',
  );
  // 2026-11-20 02:00 UTC = 09:00 WIB: Subuh lewat, Zuhur 2 jam 38 menit lagi.
  final morning = DateTime.utc(2026, 11, 20, 2);
  // 2026-11-20 13:00 UTC = 20:00 WIB: seluruh waktu sholat hari ini lewat.
  final afterIsha = DateTime.utc(2026, 11, 20, 13);

  late _FakeDaySource source;
  late _MemoryCache cache;
  late _FakeScheduler scheduler;
  late _Clock clockRef;
  late PrayerRepository repository;
  late PrayerTimesController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = _FakeDaySource();
    cache = _MemoryCache();
    scheduler = _FakeScheduler();
    // Repository dan controller harus sepakat soal "sekarang": kebijakan cache,
    // tanggal yang tampak, dan rencana pengingat memakai jam yang sama.
    clockRef = _Clock(morning);
    repository = PrayerRepository(
      client: source,
      cache: cache,
      preferences: PrayerPreferences(const AppPreferences()),
      reminderScheduler: scheduler,
      clock: clockRef.now,
    );
  });

  /// Layar berisi ListView; pada permukaan tes default kartu pengingat dan
  /// catatan sumber tidak ikut dibangun, jadi permukaan dibuat tinggi.
  void useTallScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  void buildController({DeviceLocationProvider? location, DateTime? clock}) {
    if (clock != null) clockRef.value = clock;
    controller = PrayerTimesController(
      repository: repository,
      deviceLocation: location ?? _FakeDeviceLocation(position: _device),
      cityCatalog: CityLocationCatalog(loadAsset: (_) async => _cities),
      clock: clockRef.now,
    );
  }

  /// `pumpAndSettle` tidak dipakai: hitung mundur punya ticker 1 detik sehingga
  /// settling tidak pernah selesai. Pump di bawah 1 detik lebih deterministik.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PrayerTimesScreen(controller: controller),
      ),
    );
    await settle(tester);
  }

  Future<void> startWithLocation(
    WidgetTester tester, {
    PrayerSettings? settings,
    DateTime? clock,
  }) async {
    final saved =
        settings ??
        const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
          location: jakarta,
        );
    await repository.saveSettings(saved);
    buildController(clock: clock);
    await pumpScreen(tester);
  }

  testWidgets(
    'tanpa lokasi: layar meminta lokasi, tidak ada permintaan jaringan',
    (tester) async {
      buildController();
      await pumpScreen(tester);

      expect(
        find.text('Tentukan lokasi untuk melihat waktu salat'),
        findsOneWidget,
      );
      expect(find.text('Pilih kota atau isi koordinat'), findsOneWidget);
      expect(
        find.textContaining('Tidak ada riwayat lokasi yang dikirim'),
        findsOneWidget,
      );
      expect(source.calls, 0);
    },
  );

  testWidgets('izin lokasi ditolak: alasan dan jalan manual ditampilkan', (
    tester,
  ) async {
    buildController(
      location: _FakeDeviceLocation(
        failure: const LocationFailure(LocationFailureKind.permissionDenied),
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Gunakan lokasi perangkat'));
    await settle(tester);

    expect(find.textContaining('Izin lokasi ditolak.'), findsOneWidget);
    expect(find.textContaining('koordinat secara manual'), findsOneWidget);
    expect(source.calls, 0, reason: 'tanpa koordinat tidak ada yang diminta');
  });

  testWidgets('pilih kota dari daftar lokal memicu jadwal kota itu', (
    tester,
  ) async {
    buildController();
    await pumpScreen(tester);

    await tester.tap(find.text('Pilih kota atau isi koordinat'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(find.text('Atur lokasi'), findsOneWidget);
    expect(find.textContaining('dibundel dalam aplikasi'), findsOneWidget);

    await tester.tap(find.text('Bandung'));
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(source.lastRequests, isNotEmpty);
    expect(source.lastRequests.first, contains('-6.915,107.610'));
    expect(find.text('Bandung'), findsOneWidget);
    expect(find.text('2026-11-20'), findsOneWidget);
    expect(find.text('Atur lokasi'), findsNothing);
  });

  testWidgets(
    'jadwal tampil dengan hitung mundur, hijriah, dan catatan sumber',
    (tester) async {
      await startWithLocation(tester);

      expect(find.text('Menuju Zuhur'), findsOneWidget);
      expect(find.text('02:38:00'), findsOneWidget);
      expect(find.text('Sedang berjalan: Subuh'), findsOneWidget);
      expect(find.text('10 Jumadil Akhir 1448 H'), findsOneWidget);
      expect(
        find.textContaining('metode Kementerian Agama Republik Indonesia'),
        findsOneWidget,
      );
      expect(find.textContaining('dari server'), findsOneWidget);
      expect(find.textContaining('20 November 2026'), findsOneWidget);

      for (final label in [
        'Subuh',
        'Syuruk',
        'Zuhur',
        'Asar',
        'Magrib',
        'Isya',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'waktu $label hilang');
      }
      expect(find.text('04:03'), findsOneWidget);
      expect(find.text('19:05'), findsOneWidget);
      expect(find.text('Bukan waktu salat'), findsOneWidget);

      expect(find.textContaining('AlAdhan API v1'), findsOneWidget);
      expect(
        find.textContaining('bukan penetapan resmi pemerintah'),
        findsOneWidget,
      );
    },
  );

  testWidgets('platform tanpa penjadwal tidak menjanjikan pengingat', (
    tester,
  ) async {
    scheduler.supported = false;
    await startWithLocation(
      tester,
      settings: const PrayerSettings(
        method: PrayerMethod.kemenag,
        asrMadhab: AsrMadhab.standard,
        adjustments: PrayerAdjustments(),
        location: jakarta,
        remindersEnabled: true,
      ),
    );

    expect(
      find.text('Platform ini tidak mendukung pengingat terjadwal.'),
      findsOneWidget,
    );
    // Switch tetap mati dan tidak ada izin notifikasi diminta di platform yang
    // tidak sanggup menjadwalkan apa pun.
    expect(scheduler.lastSync, isNull);
    expect(scheduler.prepares, 0);
    expect(scheduler.clears, 0);
  });

  testWidgets(
    'pengingat aktif menyebut lead menit dan hanya waktu yang tersisa',
    (tester) async {
      await startWithLocation(
        tester,
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
          location: jakarta,
          remindersEnabled: true,
          reminderLeadMinutes: 15,
        ),
      );

      expect(
        find.text('Pengingat dijadwalkan 15 menit sebelum waktu salat.'),
        findsOneWidget,
      );
      expect(scheduler.lastSync!.map((reminder) => reminder.kind), [
        PrayerKind.dhuhr,
        PrayerKind.asr,
        PrayerKind.maghrib,
        PrayerKind.isha,
      ]);
      expect(
        scheduler.lastSync!.first.fireAt,
        DateTime.utc(2026, 11, 20, 4, 23),
      );
    },
  );

  testWidgets(
    'setelah Isya hitung mundur menuju Subuh besok dan tanpa pengingat',
    (tester) async {
      await startWithLocation(
        tester,
        clock: afterIsha,
        settings: const PrayerSettings(
          method: PrayerMethod.kemenag,
          asrMadhab: AsrMadhab.standard,
          adjustments: PrayerAdjustments(),
          location: jakarta,
          remindersEnabled: true,
        ),
      );

      expect(find.text('Menuju Subuh'), findsOneWidget);
      expect(find.text('08:03:00'), findsOneWidget);
      expect(
        find.text('Tidak ada pengingat tersisa untuk jadwal yang tampil.'),
        findsOneWidget,
      );
      expect(scheduler.lastSync, isEmpty);
      expect(
        source.calls,
        2,
        reason: 'hari ini + satu permintaan hari berikutnya',
      );
    },
  );

  testWidgets('hari berikutnya dilayani dari pratarik tanpa permintaan baru', (
    tester,
  ) async {
    await startWithLocation(tester);
    expect(source.calls, 2, reason: 'hari ini + pratarik besok');

    await tester.tap(find.byTooltip('Hari berikutnya'));
    await settle(tester);

    expect(find.text('Besok'), findsOneWidget);
    expect(find.text('2026-11-21'), findsOneWidget);
    expect(find.textContaining('dari cache'), findsOneWidget);
    expect(source.calls, 2, reason: 'besok sudah tercache');

    await tester.tap(find.byTooltip('Hari sebelumnya'));
    await settle(tester);
    await tester.tap(find.byTooltip('Hari sebelumnya'));
    await settle(tester);

    expect(find.text('Kemarin'), findsOneWidget);
    expect(find.text('2026-11-19'), findsOneWidget);
    expect(source.calls, 3, reason: 'tanggal baru berarti satu permintaan');

    await tester.tap(find.text('Hari ini'));
    await settle(tester);
    expect(find.text('Hari ini'), findsWidgets);
    expect(source.calls, 3, reason: 'kembali ke hari ini memakai cache');
  });

  testWidgets('luring dengan cache basi: jadwal tetap tampil dengan catatan', (
    tester,
  ) async {
    await repository.saveLocation(jakarta);
    cache.seed(
      scheduleCacheKey(
        dateKey: '2026-11-20',
        location: jakarta,
        method: PrayerMethod.kemenag,
        asrMadhab: AsrMadhab.standard,
      ),
      _schedule(
        '2026-11-20',
        fetchedAt: morning.subtract(
          PrayerRepository.cacheAgeLimit + const Duration(hours: 2),
        ),
      ),
    );
    source.failure = const PrayerDataSourceException(
      PrayerDataFailureKind.offline,
      'Perangkat sedang luring. Jadwal yang tersimpan dipakai bila ada.',
    );
    buildController();
    await pumpScreen(tester);

    expect(
      find.textContaining('Jadwal berasal dari cache karena server'),
      findsOneWidget,
    );
    expect(find.text('04:03'), findsOneWidget);
    expect(find.textContaining('Perangkat sedang luring'), findsOneWidget);
  });

  testWidgets(
    'luring tanpa cache menampilkan kegagalan lalu pulih setelah coba lagi',
    (tester) async {
      await repository.saveLocation(jakarta);
      source.failure = const PrayerDataSourceException(
        PrayerDataFailureKind.server,
        'Layanan jadwal sholat sedang tidak dapat dihubungi.',
      );
      buildController();
      await pumpScreen(tester);

      expect(
        find.text('Layanan jadwal sholat sedang tidak dapat dihubungi.'),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.text('Ganti lokasi'), findsOneWidget);
      expect(find.text('Menuju Zuhur'), findsNothing);

      source.failure = null;
      await tester.tap(find.text('Coba lagi'));
      await settle(tester);

      expect(find.text('Menuju Zuhur'), findsOneWidget);
      expect(find.text('Coba lagi'), findsNothing);
    },
  );

  testWidgets(
    'ganti metode memakai kunci cache baru, kembali tidak mengulang permintaan',
    (tester) async {
      await startWithLocation(tester);
      final before = source.calls;

      await controller.selectMethod(PrayerMethod.byId(3));
      await settle(tester);

      expect(source.lastRequests.last, contains('|3|'));
      expect(find.textContaining('metode Muslim World League'), findsOneWidget);
      // Kunci baru berarti data baru: hari ini dan satu hari berikutnya saja.
      expect(source.calls, before + 2);

      // Kembali ke metode awal: kedua tanggal sudah tersimpan dan masih segar.
      await controller.selectMethod(PrayerMethod.kemenag);
      await settle(tester);
      expect(
        source.calls,
        before + 2,
        reason: 'cache segar bukan alasan unduh ulang',
      );

      // Tombol muat ulang memang sengaja menghubungi server, tapi hanya untuk
      // tanggal yang tampil.
      await controller.refresh();
      await settle(tester);
      expect(source.calls, before + 3);
    },
  );

  testWidgets('penyesuaian menit menggeser tampilan tanpa permintaan ulang', (
    tester,
  ) async {
    await startWithLocation(tester);
    final before = source.calls;

    await controller.setAdjustment(PrayerKind.fajr, -3);
    await settle(tester);

    expect(find.text('04:00'), findsOneWidget);
    expect(find.text('Disesuaikan -3 menit'), findsOneWidget);
    expect(
      source.calls,
      before,
      reason: 'penyesuaian bukan alasan unduh ulang',
    );
  });
}

const _cities =
    '{"locations":['
    '{"name":"Jakarta","latitude":-6.175,"longitude":106.827,'
    '"timezone":"Asia/Jakarta","country":"ID"},'
    '{"name":"Bandung","latitude":-6.9147,"longitude":107.6098,'
    '"timezone":"Asia/Jakarta","country":"ID"}]}';

PrayerDaySchedule _schedule(String dateKey, {DateTime? fetchedAt}) {
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
    methodId: 20,
    asrMadhab: AsrMadhab.standard,
    events: [
      for (final entry in times.entries)
        PrayerEvent(
          kind: entry.key,
          instant: DateTime.parse('${dateKey}T${entry.value}:00+07:00').toUtc(),
          locationOffset: const Duration(hours: 7),
        ),
    ],
    source: ScheduleSource.live,
    hijri: const HijriDate(
      day: 10,
      month: 6,
      year: 1448,
      monthNameEn: 'Jumādá al-ākhirah',
      monthNameAr: 'جُمادى الآخرة',
      weekdayEn: "Al Juma'a",
      method: 'HJCoSA',
    ),
    fetchedAt: fetchedAt ?? DateTime.utc(2026, 11, 19, 20),
  );
}

class _Clock {
  _Clock(this.value);

  DateTime value;

  DateTime now() => value;
}

class _FakeDeviceLocation implements DeviceLocationProvider {
  _FakeDeviceLocation({this.position = _device, this.failure});

  final WorshipLocation position;
  final LocationFailure? failure;

  @override
  Future<WorshipLocation> locate() async {
    final error = failure;
    if (error != null) throw error;
    return position;
  }
}

const _device = WorshipLocation(
  name: 'Lokasi perangkat',
  latitude: -6.175,
  longitude: 106.827,
  source: LocationSource.gps,
  timezoneId: 'Asia/Jakarta',
);

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
    return _schedule(dateKey);
  }
}

class _MemoryCache implements PrayerCacheStore {
  final stored = <String, PrayerDaySchedule>{};

  void seed(String key, PrayerDaySchedule schedule) => stored[key] = schedule;

  @override
  Future<void> save(
    PrayerDaySchedule schedule, {
    required String cacheKey,
  }) async => stored[cacheKey] = schedule;

  @override
  Future<PrayerDaySchedule?> load(String cacheKey) async {
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
  Future<void> pruneOlderThan(Duration age) async {}
}

class _FakeScheduler implements PrayerReminderScheduler {
  bool supported = true;
  bool prepareResult = true;
  List<PrayerReminder>? lastSync;
  int prepares = 0;
  int clears = 0;

  @override
  bool get supportsPlatform => supported;

  @override
  Future<bool> prepare() async {
    prepares++;
    return prepareResult;
  }

  @override
  Future<void> sync(List<PrayerReminder> reminders) async =>
      lastSync = reminders;

  @override
  Future<void> clear() async => clears++;
}
