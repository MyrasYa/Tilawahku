import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:tilawahku/features/qibla/presentation/qibla_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<QiblaController> pumpScreen(
    WidgetTester tester, {
    WorshipLocation? location,
    _FakeHeadingSource? heading,
    Duration staleAfter = const Duration(days: 1),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const prefs = PrayerPreferences(AppPreferences());
    if (location != null) await prefs.saveLocation(location);
    final controller = QiblaController(
      store: QiblaLocationStore(
        preferences: prefs,
        deviceLocation: const _FakeDeviceLocation(),
        cityCatalog: CityLocationCatalog(loadAsset: (_) async => _cities),
      ),
      headingSource: heading ?? _FakeHeadingSource(available: false),
      headingStaleAfter: staleAfter,
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: QiblaScreen(controller: controller),
      ),
    );
    await settle(tester);
    return controller;
  }

  testWidgets('tanpa lokasi: panel permintaan, bukan dial', (tester) async {
    await pumpScreen(tester);
    expect(
      find.text('Tentukan lokasi untuk menghitung kiblat'),
      findsOneWidget,
    );
    expect(find.text('Gunakan lokasi perangkat'), findsOneWidget);
    expect(find.text('Pilih kota atau isi koordinat'), findsOneWidget);
    expect(find.text('Dial manual'), findsNothing);
  });

  testWidgets('Jakarta: bearing, jarak, lokasi, dan mode manual', (
    tester,
  ) async {
    await pumpScreen(tester, location: _jakarta);
    expect(find.text('Arah Kiblat'), findsOneWidget);
    expect(find.text('Jakarta'), findsOneWidget);
    expect(find.text('295.1°'), findsOneWidget);
    expect(find.textContaining("7.917 km ke Ka'bah"), findsOneWidget);
    expect(find.text('Dial manual'), findsWidgets);
    expect(find.text('Kompas perangkat'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('bukan heading fisik perangkat'), findsWidgets);
  });

  testWidgets('bacaan live mengganti mode dan menyembunyikan penggeser', (
    tester,
  ) async {
    final heading = _FakeHeadingSource();
    await pumpScreen(tester, location: _jakarta, heading: heading);
    heading.emit(headingDegrees: 12, accuracyDegrees: 5);
    await settle(tester);

    expect(find.text('Kompas perangkat'), findsWidgets);
    expect(find.text('Heading perangkat 12.0° dari utara'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Cara memakai dial manual'), findsNothing);
  });

  testWidgets('kalibrasi tampil saat ketelitian rendah', (tester) async {
    final heading = _FakeHeadingSource();
    await pumpScreen(tester, location: _jakarta, heading: heading);
    heading.emit(headingDegrees: 40, accuracyDegrees: 30);
    await settle(tester);
    expect(find.textContaining('Ketelitian kompas rendah'), findsOneWidget);
    expect(find.textContaining('angka 8'), findsOneWidget);
  });

  testWidgets('tombol lokasi perangkat yang gagal menampilkan saran izin', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const prefs = PrayerPreferences(AppPreferences());
    final controller = QiblaController(
      store: QiblaLocationStore(
        preferences: prefs,
        deviceLocation: const _FakeDeviceLocation(
          failure: LocationFailure(LocationFailureKind.permissionDenied),
        ),
        cityCatalog: CityLocationCatalog(loadAsset: (_) async => _cities),
      ),
      headingSource: _FakeHeadingSource(available: false),
    );
    await tester.pumpWidget(
      MaterialApp(home: QiblaScreen(controller: controller)),
    );
    await settle(tester);
    await tester.tap(find.text('Gunakan lokasi perangkat'));
    await settle(tester);
    expect(find.textContaining('Izin lokasi ditolak'), findsOneWidget);
  });
}

class _FakeHeadingSource implements QiblaHeadingSource {
  _FakeHeadingSource({this.available = true});

  bool available;
  final _controller = StreamController<QiblaHeadingSample>.broadcast();

  void emit({double? headingDegrees, double? accuracyDegrees}) {
    _controller.add(
      QiblaHeadingSample(
        headingDegrees: headingDegrees,
        accuracyDegrees: accuracyDegrees,
        receivedAt: DateTime.utc(2026, 11, 21),
      ),
    );
  }

  @override
  Future<bool> hasSensors() async => available;

  @override
  Stream<QiblaHeadingSample> watch() => _controller.stream;
}

class _FakeDeviceLocation implements DeviceLocationProvider {
  const _FakeDeviceLocation({this.failure});

  final LocationFailure? failure;

  @override
  Future<WorshipLocation> locate() async {
    final error = failure;
    if (error != null) throw error;
    return _jakarta;
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

const _cities =
    '{"locations":['
    '{"name":"Jakarta","latitude":-6.175,"longitude":106.827,'
    '"timezone":"Asia/Jakarta","country":"ID"}]}';
