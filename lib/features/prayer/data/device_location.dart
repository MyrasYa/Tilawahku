import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/prayer_models.dart';

enum LocationFailureKind {
  serviceDisabled('Lokasi perangkat belum aktif.', 'Aktifkan layanan lokasi, lalu coba lagi.'),
  permissionDenied(
    'Izin lokasi ditolak.',
    'Anda masih bisa memasukkan kota atau koordinat secara manual.',
  ),
  permissionDeniedForever(
    'Izin lokasi dicabut permanen.',
    'Buka pengaturan aplikasi dan izinkan akses lokasi, atau isi lokasi manual.',
  ),
  permissionUnableToDetermine(
    'Status izin lokasi tidak dapat dibaca.',
    'Coba lagi, atau isi lokasi manual.',
  ),
  timeout('Permintaan lokasi melebihi batas waktu.', 'Coba lagi di dekat jendela atau area terbuka.'),
  unavailable(
    'Perangkat tidak memberikan posisi.',
    'Peramban atau perangkat menolak memberi lokasi; gunakan input manual.',
  );

  const LocationFailureKind(this.message, this.suggestion);

  final String message;
  final String suggestion;
}

class LocationFailure implements Exception {
  const LocationFailure(this.kind);

  final LocationFailureKind kind;

  String get message => kind.message;

  String get suggestion => kind.suggestion;

  @override
  String toString() => kind.message;
}

/// Satu-satunya pintu pengambilan posisi perangkat untuk seluruh aplikasi.
abstract interface class DeviceLocationProvider {
  /// Melempar [LocationFailure], bukan `null`, agar layar bisa menampilkan
  /// alasan yang berbeda (izin mati, GPS mati, peramban menolak).
  Future<WorshipLocation> locate();
}

typedef PositionReader =
    Future<Position> Function(LocationSettings settings);

class GeolocatorDeviceLocation implements DeviceLocationProvider {
  const GeolocatorDeviceLocation({PositionReader? readPosition})
    : _readPosition = readPosition;

  static const Duration timeLimit = Duration(seconds: 15);

  final PositionReader? _readPosition;

  @override
  Future<WorshipLocation> locate() async {
    // Di web tidak ada konsep "layanan lokasi", dan geolocator_web selalu
    // mengembalikan true; memeriksa izin lewat Geolocator di sana juga tidak
    // reliably didukung, jadi langsung minta posisi ke peramban.
    if (!kIsWeb) {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure(LocationFailureKind.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          throw const LocationFailure(LocationFailureKind.permissionDenied);
        case LocationPermission.deniedForever:
          throw const LocationFailure(
            LocationFailureKind.permissionDeniedForever,
          );
        case LocationPermission.unableToDetermine:
          throw const LocationFailure(
            LocationFailureKind.permissionUnableToDetermine,
          );
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
    }

    final settings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: timeLimit,
    );
    final reader = _readPosition;
    try {
      final position = reader == null
          ? await Geolocator.getCurrentPosition(locationSettings: settings)
          : await reader(settings);
      return WorshipLocation(
        name: 'Posisi perangkat',
        latitude: position.latitude,
        longitude: position.longitude,
        source: LocationSource.gps,
      );
    } on TimeoutException {
      throw const LocationFailure(LocationFailureKind.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationFailureKind.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationFailure(LocationFailureKind.permissionDenied);
    } on Exception catch (error) {
      // Geolocator melempar PlatformException dengan kode yang berbeda-beda
      // per platform; apa pun bentuknya, lokasi manual tetap tersedia.
      throw LocationFailure(
        _kindOfMessage('${error.runtimeType} $error') ??
            LocationFailureKind.unavailable,
      );
    }
  }

  static LocationFailureKind? _kindOfMessage(String message) {
    final lowered = message.toLowerCase();
    if (lowered.contains('timeout') || lowered.contains('time limit')) {
      return LocationFailureKind.timeout;
    }
    if (lowered.contains('denied') || lowered.contains('permission')) {
      return LocationFailureKind.permissionDenied;
    }
    if (lowered.contains('service') || lowered.contains('disabled')) {
      return LocationFailureKind.serviceDisabled;
    }
    return null;
  }
}
