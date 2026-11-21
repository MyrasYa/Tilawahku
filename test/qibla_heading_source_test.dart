import 'package:flutter/foundation.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/qibla/data/qibla_heading_source_native.dart';
import 'package:tilawahku/features/qibla/data/qibla_heading_source_unsupported.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('platform tanpa kompas tidak mengada-adakan heading', () async {
    const source = UnsupportedQiblaHeadingSource();
    expect(await source.hasSensors(), isFalse);
    expect(await source.watch().isEmpty, isTrue);
  });

  test(
    'Windows/macOS/Linux dilaporkan tanpa sensor, tanpa memanggil plugin',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      var probed = false;
      final source = DeviceCompassHeadingSource(
        hasSensors: () async {
          probed = true;
          return true;
        },
      );
      expect(await source.hasSensors(), isFalse);
      expect(probed, isFalse);
    },
  );

  test(
    'Android memanggil plugin dan hanya true yang dianggap tersedia',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        await DeviceCompassHeadingSource(
          hasSensors: () async => true,
        ).hasSensors(),
        isTrue,
      );
      expect(
        await DeviceCompassHeadingSource(
          hasSensors: () async => false,
        ).hasSensors(),
        isFalse,
      );
      expect(
        await DeviceCompassHeadingSource(
          hasSensors: () async => null,
        ).hasSensors(),
        isFalse,
      );
    },
  );

  test(
    'kegagalan probe plugin menjadi tidak tersedia, bukan exception',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final source = DeviceCompassHeadingSource(
        hasSensors: () async => throw StateError('channel down'),
      );
      expect(await source.hasSensors(), isFalse);
    },
  );

  test('event plugin dipetakan apa adanya, termasuk heading null', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final clock = DateTime.utc(2026, 11, 21, 4);
    final source = DeviceCompassHeadingSource(
      events: () => Stream<CompassEvent>.fromIterable([
        CompassEvent.fromList(const [295.1, 10.0, 4.0]),
        CompassEvent.fromList(const [null, null, null]),
      ]),
      clock: () => clock,
    );

    final samples = await source.watch().toList();
    expect(samples, hasLength(2));
    expect(samples.first.headingDegrees, 295.1);
    expect(samples.first.accuracyDegrees, 4.0);
    expect(samples.first.receivedAt, clock);
    expect(samples.first.isUsable, isTrue);
    expect(samples.last.headingDegrees, isNull);
    expect(samples.last.isUsable, isFalse);
  });

  test(
    'stream plugin null menghasilkan stream kosong, bukan heading palsu',
    () async {
      final source = DeviceCompassHeadingSource(events: () => null);
      expect(await source.watch().isEmpty, isTrue);
    },
  );

  test('watch yang melempar menjadi stream kosong', () async {
    final source = DeviceCompassHeadingSource(
      events: () => throw StateError('no channel'),
    );
    expect(await source.watch().isEmpty, isTrue);
  });
}
