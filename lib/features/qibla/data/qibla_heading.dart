import '../domain/qibla_direction.dart';

/// Satu sampel heading dari sensor, atau kosong bila perangkat tidak memberi
/// angka yang sah.
class QiblaHeadingSample {
  const QiblaHeadingSample({
    this.headingDegrees,
    this.accuracyDegrees,
    required this.receivedAt,
  });

  /// Arah tepi atas perangkat terhadap utara, derajat. `null` = tidak sah.
  final double? headingDegrees;

  /// Perkiraan deviasi dalam derajat. Negatif = status sensor unreliable.
  final double? accuracyDegrees;

  final DateTime receivedAt;

  bool get isUsable => isUsableHeading(headingDegrees, accuracyDegrees);

  bool get needsCalibration => headingNeedsCalibration(accuracyDegrees);
}

/// Sumber heading. Implementasi perangkat ada di berkas native; tes menyuntikkan
/// sumber palsu. Tidak meminta izin lokasi — itu hanya lewat pemilihan lokasi.
abstract interface class QiblaHeadingSource {
  Future<bool> hasSensors();

  Stream<QiblaHeadingSample> watch();
}
