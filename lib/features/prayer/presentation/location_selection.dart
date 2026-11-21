import '../domain/prayer_models.dart';

/// Permukaan yang dibutuhkan lembar pemilihan lokasi.
///
/// Waktu salat dan arah kiblat memakai lembar yang sama dan menyimpan hasil
/// pilihan pada preferensi yang sama, jadi satu kali pilih kota berlaku untuk
/// keduanya dan tidak ada kedua "location manager".
abstract interface class LocationSelection {
  bool get busy;

  /// Alasan kegagalan atau perbaikan yang bisa dilakukan pengguna, mis. izin
  /// lokasi ditolak. `null` berarti tidak ada pesan.
  String? get locationMessage;

  /// Kota yang dibundel dalam aplikasi.
  List<WorshipLocation> get cities;

  WorshipLocation? get selectedLocation;

  Future<void> useDeviceLocation();

  Future<void> selectCity(WorshipLocation city);

  Future<void> enterCoordinates({
    required String name,
    required double latitude,
    required double longitude,
  });
}
