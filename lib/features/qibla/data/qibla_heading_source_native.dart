import 'package:flutter/foundation.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';

import 'qibla_heading.dart';

QiblaHeadingSource createQiblaHeadingSource() => DeviceCompassHeadingSource();

/// Heading dari `flutter_device_compass`. Gagal plugin atau heading `null`
/// diteruskan apa adanya — pemanggil yang memutuskan fallback manual.
class DeviceCompassHeadingSource implements QiblaHeadingSource {
  DeviceCompassHeadingSource({
    Future<bool?> Function()? hasSensors,
    Stream<CompassEvent>? Function()? events,
    DateTime Function()? clock,
  }) : _hasSensors = hasSensors,
       _events = events,
       _clock = clock ?? DateTime.now;

  final Future<bool?> Function()? _hasSensors;
  final Stream<CompassEvent>? Function()? _events;
  final DateTime Function() _clock;

  @override
  Future<bool> hasSensors() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        break;
      default:
        return false;
    }
    try {
      final probe = _hasSensors ?? () => FlutterCompass.hasSensors;
      return await probe() == true;
    } on Object {
      return false;
    }
  }

  @override
  Stream<QiblaHeadingSample> watch() {
    try {
      final stream = (_events ?? () => FlutterCompass.events)();
      if (stream == null) return const Stream.empty();
      return stream.map(
        (event) => QiblaHeadingSample(
          headingDegrees: event.heading,
          accuracyDegrees: event.accuracy,
          receivedAt: _clock(),
        ),
      );
    } on Object {
      return const Stream.empty();
    }
  }
}
