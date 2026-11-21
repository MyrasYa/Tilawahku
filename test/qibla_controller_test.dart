import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/prayer/data/city_location_catalog.dart';
import 'package:tilawahku/features/prayer/data/device_location.dart';
import 'package:tilawahku/features/prayer/data/prayer_preferences.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';
import 'package:tilawahku/features/qibla/data/qibla_heading.dart';
import 'package:tilawahku/features/qibla/data/qibla_location_store.dart';
import 'package:tilawahku/features/qibla/presentation/qibla_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tanpa lokasi tersimpan meminta lokasi, tanpa heading palsu', () async {
    final controller = await _started();
    expect(controller.state, QiblaLoadState.needsLocation);
    expect(controller.reading, isNull);
    expect(controller.headingMode, QiblaHeadingMode.manual);
    expect(controller.isLiveCompass, isFalse);
    controller.dispose();
  });

  test(
    'lokasi PrayerPreferences dipakai bersama, bearing Jakarta tampil',
    () async {
      const prefs = PrayerPreferences(AppPreferences());
      await prefs.saveLocation(_jakarta);
      final controller = await _started(preferences: prefs);
      expect(controller.state, QiblaLoadState.ready);
      expect(controller.location?.name, 'Jakarta');
      expect(controller.reading?.bearingDegrees, closeTo(295.146, 0.001));
      expect(controller.headingMode, QiblaHeadingMode.manual);
      expect(controller.headingModeLabel, 'Dial manual');
      controller.dispose();
    },
  );

  test('pilih kota kiblat tersimpan di preferensi waktu salat', () async {
    const prefs = PrayerPreferences(AppPreferences());
    final controller = await _started(preferences: prefs);
    await controller.selectCity(_jakarta);
    expect((await prefs.load()).location?.name, 'Jakarta');
    expect(controller.reading?.hasBearing, isTrue);
    controller.dispose();
  });

  test('izin lokasi ditolak tidak mengarang koordinat', () async {
    final controller = await _started(
      device: _FakeDeviceLocation(
        failure: const LocationFailure(LocationFailureKind.permissionDenied),
      ),
    );
    await controller.useDeviceLocation();
    expect(controller.location, isNull);
    expect(controller.locationMessage, contains('Izin lokasi ditolak'));
    expect(controller.state, QiblaLoadState.needsLocation);
    controller.dispose();
  });

  test('koordinat di luar rentang ditolak', () async {
    final controller = await _started();
    await controller.enterCoordinates(
      name: 'Salah',
      latitude: 120,
      longitude: 0,
    );
    expect(controller.location, isNull);
    expect(
      controller.locationMessage,
      contains('Koordinat harus dalam rentang'),
    );
    controller.dispose();
  });

  test('sensor tidak tersedia tetap di dial manual', () async {
    final heading = _FakeHeadingSource(available: false);
    final controller = await _started(location: _jakarta, heading: heading);
    expect(controller.sensorsAvailable, isFalse);
    expect(controller.headingMode, QiblaHeadingMode.manual);
    expect(controller.compassMessage, contains('tidak tersedia'));
    expect(heading.watchCalls, 0);
    controller.dispose();
  });

  test('bacaan sah mengaktifkan kompas live dan rumus relatif', () async {
    final heading = _FakeHeadingSource();
    final controller = await _started(location: _jakarta, heading: heading);
    expect(controller.headingMode, QiblaHeadingMode.manual);

    heading.emit(headingDegrees: 10, accuracyDegrees: 4);
    await Future<void>.delayed(Duration.zero);

    expect(controller.headingMode, QiblaHeadingMode.live);
    expect(controller.dialDegrees, 10);
    expect(controller.headingModeLabel, 'Kompas perangkat');
    expect(controller.deviceHeadingLabel, '10.0° dari utara');
    expect(
      controller.markerDegrees,
      closeTo(relativeQiblaFrom(295.146, 10), 0.01),
    );
    controller.rotateDial(20);
    expect(
      controller.dialDegrees,
      10,
      reason: 'geser manual diabaikan saat live',
    );
    controller.dispose();
  });

  test(
    'heading null atau akurasi negatif tidak dipakai sebagai live',
    () async {
      final heading = _FakeHeadingSource();
      final controller = await _started(location: _jakarta, heading: heading);
      heading.emit(headingDegrees: null, accuracyDegrees: 3);
      await Future<void>.delayed(Duration.zero);
      expect(controller.headingMode, QiblaHeadingMode.manual);
      expect(controller.headingUnreliable, isTrue);

      heading.emit(headingDegrees: 40, accuracyDegrees: -1);
      await Future<void>.delayed(Duration.zero);
      expect(controller.headingMode, QiblaHeadingMode.manual);
      expect(controller.compassMessage, contains('tidak sah'));
      controller.dispose();
    },
  );

  test('ketelitian rendah tetap live tetapi menampilkan kalibrasi', () async {
    final heading = _FakeHeadingSource();
    final controller = await _started(location: _jakarta, heading: heading);
    heading.emit(headingDegrees: 20, accuracyDegrees: 25);
    await Future<void>.delayed(Duration.zero);
    expect(controller.headingMode, QiblaHeadingMode.live);
    expect(controller.headingUnreliable, isTrue);
    expect(controller.compassMessage, contains('angka 8'));
    controller.dispose();
  });

  test('error stream dan watch yang gagal jatuh ke manual', () async {
    final heading = _FakeHeadingSource();
    final controller = await _started(location: _jakarta, heading: heading);
    heading.emit(headingDegrees: 5, accuracyDegrees: 2);
    await Future<void>.delayed(Duration.zero);
    expect(controller.isLiveCompass, isTrue);

    heading.emitError();
    await Future<void>.delayed(Duration.zero);
    expect(controller.headingMode, QiblaHeadingMode.manual);
    expect(controller.sensorsAvailable, isFalse);
    expect(controller.compassMessage, contains('tidak dapat dibaca'));
    controller.dispose();

    final throwing = _FakeHeadingSource(watchThrows: true);
    final second = await _started(location: _jakarta, heading: throwing);
    expect(second.headingMode, QiblaHeadingMode.manual);
    expect(second.sensorsAvailable, isFalse);
    second.dispose();
  });

  test('bacaan basi mengembalikan dial manual', () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues({});
      final heading = _FakeHeadingSource();
      late QiblaController controller;
      unawaited(() async {
        controller = await _started(location: _jakarta, heading: heading);
      }());
      async.flushMicrotasks();
      heading.emit(headingDegrees: 15, accuracyDegrees: 3);
      async.flushMicrotasks();
      expect(controller.headingMode, QiblaHeadingMode.live);

      async.elapse(const Duration(seconds: 3));
      expect(controller.headingMode, QiblaHeadingMode.manual);
      expect(controller.compassMessage, contains('terhenti'));
      controller.dispose();
      async.flushMicrotasks();
    });
  });

  test('pause memutus langganan dan resume memasang ulang', () async {
    final heading = _FakeHeadingSource();
    final controller = await _started(location: _jakarta, heading: heading);
    heading.emit(headingDegrees: 8, accuracyDegrees: 2);
    await Future<void>.delayed(Duration.zero);
    expect(heading.watchCalls, 1);
    expect(controller.isLiveCompass, isTrue);

    await controller.pauseHeading();
    expect(controller.headingMode, QiblaHeadingMode.manual);
    expect(heading.activeListeners, 0);

    heading.emit(headingDegrees: 90, accuracyDegrees: 2);
    await Future<void>.delayed(Duration.zero);
    expect(controller.dialDegrees, 8, reason: 'sampel setelah pause diabaikan');

    await controller.resumeHeading();
    expect(heading.watchCalls, 2);
    heading.emit(headingDegrees: 33, accuracyDegrees: 2);
    await Future<void>.delayed(Duration.zero);
    expect(controller.dialDegrees, 33);
    controller.dispose();
  });

  test('dispose memutus sensor dan menolak sampel berikutnya', () async {
    final heading = _FakeHeadingSource();
    final controller = await _started(location: _jakarta, heading: heading);
    heading.emit(headingDegrees: 1, accuracyDegrees: 2);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    expect(heading.activeListeners, 0);

    heading.emit(headingDegrees: 180, accuracyDegrees: 2);
    await Future<void>.delayed(Duration.zero);
    expect(controller.dialDegrees, 1);
  });

  test('dial manual berputar dan reset ke utara', () async {
    final controller = await _started(
      location: _jakarta,
      heading: _FakeHeadingSource(available: false),
    );
    controller.rotateDial(40);
    expect(controller.dialDegrees, 40);
    controller.setDial(350);
    controller.rotateDial(20);
    expect(controller.dialDegrees, 10);
    controller.resetDial();
    expect(controller.dialDegrees, 0);
    expect(controller.headingMode, QiblaHeadingMode.manual);
    controller.dispose();
  });
}

double relativeQiblaFrom(double bearing, double heading) {
  final rest = (bearing - heading) % 360;
  return rest < 0 ? rest + 360 : rest;
}

Future<QiblaController> _started({
  PrayerPreferences? preferences,
  WorshipLocation? location,
  DeviceLocationProvider? device,
  _FakeHeadingSource? heading,
}) async {
  final prefs = preferences ?? const PrayerPreferences(AppPreferences());
  if (location != null) await prefs.saveLocation(location);
  final controller = QiblaController(
    store: QiblaLocationStore(
      preferences: prefs,
      deviceLocation: device ?? const _FakeDeviceLocation(),
      cityCatalog: CityLocationCatalog(loadAsset: (_) async => _cities),
    ),
    headingSource: heading ?? _FakeHeadingSource(available: false),
  );
  await controller.start();
  return controller;
}

class _FakeHeadingSource implements QiblaHeadingSource {
  _FakeHeadingSource({this.available = true, this.watchThrows = false})
    : _controller = StreamController<QiblaHeadingSample>.broadcast() {
    _controller.onListen = () => activeListeners++;
    _controller.onCancel = () => activeListeners--;
  }

  bool available;
  bool watchThrows;
  final StreamController<QiblaHeadingSample> _controller;
  var watchCalls = 0;
  var activeListeners = 0;

  void emit({double? headingDegrees, double? accuracyDegrees}) {
    _controller.add(
      QiblaHeadingSample(
        headingDegrees: headingDegrees,
        accuracyDegrees: accuracyDegrees,
        receivedAt: DateTime.utc(2026, 11, 21),
      ),
    );
  }

  void emitError() => _controller.addError(Exception('sensor failed'));

  @override
  Future<bool> hasSensors() async => available;

  @override
  Stream<QiblaHeadingSample> watch() {
    watchCalls++;
    if (watchThrows) throw StateError('watch failed');
    return _controller.stream;
  }
}

class _FakeDeviceLocation implements DeviceLocationProvider {
  const _FakeDeviceLocation({this.failure});

  final LocationFailure? failure;

  @override
  Future<WorshipLocation> locate() async {
    final error = failure;
    if (error != null) throw error;
    return _device;
  }
}

const _jakarta = WorshipLocation(
  name: 'Jakarta',
  latitude: -6.175,
  longitude: 106.827,
  source: LocationSource.saved,
  timezoneId: 'Asia/Jakarta',
  country: 'ID',
);

const _device = WorshipLocation(
  name: 'Lokasi perangkat',
  latitude: -6.175,
  longitude: 106.827,
  source: LocationSource.gps,
);

const _cities =
    '{"locations":['
    '{"name":"Jakarta","latitude":-6.175,"longitude":106.827,'
    '"timezone":"Asia/Jakarta","country":"ID"}]}';
