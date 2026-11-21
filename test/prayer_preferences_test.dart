import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/prayer/data/city_location_catalog.dart';
import 'package:tilawahku/features/prayer/data/prayer_preferences.dart';
import 'package:tilawahku/features/prayer/domain/prayer_method.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const jakarta = WorshipLocation(
    name: 'Jakarta',
    latitude: -6.175,
    longitude: 106.827,
    source: LocationSource.saved,
    timezoneId: 'Asia/Jakarta',
    country: 'ID',
  );

  group('PrayerPreferences', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'tanpa nilai tersimpan memakai aturan Indonesia dan tanpa pengingat',
      () async {
        const preferences = PrayerPreferences(AppPreferences());
        final settings = await preferences.load();

        expect(settings.method, PrayerMethod.kemenag);
        expect(settings.asrMadhab, AsrMadhab.standard);
        expect(settings.adjustments.isEmpty, isTrue);
        expect(settings.location, isNull);
        expect(settings.hasValidLocation, isFalse);
        expect(settings.remindersEnabled, isFalse);
        expect(settings.reminderLeadMinutes, 10);
        expect(settings.reminderKinds, isEmpty);
      },
    );

    test('semua pengaturan dipulang-simpan utuh', () async {
      const preferences = PrayerPreferences(AppPreferences());
      final saved = PrayerSettings(
        method: PrayerMethod.byId(4),
        asrMadhab: AsrMadhab.hanafi,
        adjustments: const PrayerAdjustments()
            .set(PrayerKind.fajr, -3)
            .set(PrayerKind.maghrib, 2),
        location: jakarta,
        remindersEnabled: true,
        reminderLeadMinutes: 20,
        reminderKinds: const {PrayerKind.fajr, PrayerKind.isha},
      );

      await preferences.save(saved);
      final loaded = await preferences.load();

      expect(loaded.method.aladhanId, 4);
      expect(loaded.asrMadhab, AsrMadhab.hanafi);
      expect(loaded.adjustments.minutesFor(PrayerKind.fajr), -3);
      expect(loaded.adjustments.minutesFor(PrayerKind.maghrib), 2);
      expect(loaded.location?.name, 'Jakarta');
      expect(loaded.location?.timezoneId, 'Asia/Jakarta');
      expect(loaded.hasValidLocation, isTrue);
      expect(loaded.remindersEnabled, isTrue);
      expect(loaded.reminderLeadMinutes, 20);
      expect(loaded.reminderKinds, {PrayerKind.fajr, PrayerKind.isha});
    });

    test(
      'nilai rusak dibaca sebagai default, bukan membuat layar gagal',
      () async {
        SharedPreferences.setMockInitialValues({
          'prayer_method_id': 999,
          'prayer_asr_madhab': 'mazhab-abstrak',
          'prayer_adjustments': 'bukan json',
          'prayer_location':
              '{"name":"Entah","latitude":120.0,"longitude":0.0}',
          'prayer_reminder_lead_minutes': 999,
          'prayer_reminder_kinds': '["sunrise","fajr","tidak-ada"]',
        });
        const preferences = PrayerPreferences(AppPreferences());
        final settings = await preferences.load();

        expect(settings.method, PrayerMethod.defaultMethod);
        expect(settings.asrMadhab, AsrMadhab.standard);
        expect(settings.adjustments.isEmpty, isTrue);
        expect(settings.location, isNull, reason: 'koordinat di luar rentang');
        expect(settings.reminderLeadMinutes, PrayerSettings.maxLeadMinutes);
        expect(settings.reminderKinds, {PrayerKind.fajr});
      },
    );

    test('lead negatif kembali ke bawaan', () async {
      SharedPreferences.setMockInitialValues({
        'prayer_reminder_lead_minutes': -5,
      });
      final settings = await const PrayerPreferences(AppPreferences()).load();
      expect(settings.reminderLeadMinutes, 10);
    });

    test(
      'lokasi bisa disimpan dan dihapus terpisah dari pengaturan lain',
      () async {
        const preferences = PrayerPreferences(AppPreferences());
        await preferences.saveLocation(jakarta);
        expect((await preferences.load()).location?.name, 'Jakarta');

        await preferences.clearLocation();
        final after = await preferences.load();
        expect(after.location, isNull);
        expect(
          after.method,
          PrayerMethod.kemenag,
          reason: 'pengaturan lain utuh',
        );
      },
    );

    test(
      'kunci pref diberi namespace prayer_ agar tidak menimpa fitur lama',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await const PrayerPreferences(AppPreferences()).save(
          const PrayerSettings(
            method: PrayerMethod.kemenag,
            asrMadhab: AsrMadhab.standard,
            adjustments: PrayerAdjustments(),
            location: jakarta,
          ),
        );
        final keys = prefs.getKeys().toList();
        expect(keys, everyElement(startsWith('prayer_')));
        expect(
          keys,
          isNot(
            contains(
              anyOf('dark_mode', 'selected_voice_id', 'onboarding_complete'),
            ),
          ),
        );
      },
    );
  });

  group('CityLocationCatalog', () {
    test('berkas yang dibundel terbaca dan punya catatan sumber', () async {
      final cities = await CityLocationCatalog().load();

      expect(cities, isNotEmpty);
      expect(cities.length, greaterThanOrEqualTo(30));
      expect(
        cities.every((city) => city.source == LocationSource.saved),
        isTrue,
      );
      expect(
        cities.every(
          (city) =>
              WorshipLocation.coordinateInRange(city.latitude, city.longitude),
        ),
        isTrue,
      );
      expect(
        cities.map((city) => city.name),
        containsAll(['Jakarta', 'Bandung', 'Mekah', 'Madinah']),
      );
      expect(
        cities.firstWhere((city) => city.name == 'Jakarta').timezoneId,
        'Asia/Jakarta',
      );
    });

    test(
      'hasil load kedua diambil dari memori, bukan baca berkas ulang',
      () async {
        var reads = 0;
        final catalog = CityLocationCatalog(
          loadAsset: (_) async {
            reads++;
            return '{"locations":[{"name":"Jakarta","latitude":-6.175,'
                '"longitude":106.827,"timezone":"Asia/Jakarta"}]}';
          },
        );

        await catalog.load();
        await catalog.load();
        expect(reads, 1);
      },
    );

    test('entri cacat dilewati, berkas rusak menjadi daftar kosong', () {
      final cities = CityLocationCatalog.decode('''
        {"locations":[
          {"name":"Baik","latitude":-6.1,"longitude":106.8,"timezone":"Asia/Jakarta"},
          {"name":"TanpaKoordinat"},
          {"name":"DiLuarRentang","latitude":120,"longitude":0},
          {"latitude":-6.1,"longitude":106.8},
          {"name":"Teks","latitude":"-6.1","longitude":106.8}
        ]}
        ''');
      expect(cities, hasLength(1));
      expect(cities.single.name, 'Baik');
      expect(cities.single.source, LocationSource.saved);
      expect(CityLocationCatalog.decode('bukan json'), isEmpty);
      expect(CityLocationCatalog.decode('{"locations":"x"}'), isEmpty);
    });
  });
}
