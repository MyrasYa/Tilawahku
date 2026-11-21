import 'dart:math' as math;

import '../../prayer/domain/prayer_models.dart';

/// Titik acuan arah kiblat: posisi Ka'bah.
///
/// 21.4225° LU / 39.8262° BT (21°25′21″N 39°49′34″E) adalah pasangan koordinat
/// yang dipakai AlAdhan pada `/v1/qibla`: bearing dari rumus di bawah cocok
/// dengan nilai layanan itu sampai < 0,001° untuk tujuh kota (bukti:
/// `docs/prd-07-qibla.md`).
const WorshipLocation kaabaLocation = WorshipLocation(
  name: 'Mekah — Ka\'bah',
  latitude: 21.4225,
  longitude: 39.8262,
  source: LocationSource.saved,
  timezoneId: 'Asia/Riyadh',
  country: 'SA',
);

/// Radius rata-rata Bumi untuk jarak lingkaran besar.
const double earthRadiusKm = 6371;

/// Kurang dari jarak ini dianggap berada di Ka'bah: arah menuju titik yang
/// sedang dihuni tidak terdefinisi.
const double undefinedNearKm = 1;

/// Lebih dari setengah keliling Bumi: pengguna di antipod Ka'bah, tempat satu
/// derajat putaran sudah mengubah arah secara besar.
const double undefinedFarKm = 20000;

enum QiblaUndefinedReason {
  atLocation(
    'Lokasi ini berada di Ka\'bah, jadi arah hadap bukan satu garis '
    'tunggal.',
  ),
  antipode(
    'Lokasi ini berada di sisi Bumi yang berlawanan dengan Ka\'bah, sehingga '
    'arahnya sangat sensitif terhadap perubahan kecil koordinat.',
  ),
  invalidCoordinates('Koordinat tidak sah, jadi arah kiblat tidak dihitung.');

  const QiblaUndefinedReason(this.messageId);

  final String messageId;
}

/// Hasil hitung arah kiblat untuk satu koordinat.
class QiblaReading {
  const QiblaReading._({
    required this.distanceKm,
    this.bearingDegrees,
    this.undefinedReason,
  });

  /// Jarak lingkaran besar ke Ka'bah dalam kilometer.
  final double distanceKm;

  /// Bearing awal dari utara sejati, 0 ≤ nilai < 360. Kosong hanya bila arah
  /// tidak terdefinisi, lihat [undefinedReason].
  final double? bearingDegrees;

  final QiblaUndefinedReason? undefinedReason;

  bool get hasBearing => bearingDegrees != null;

  String get bearingLabel =>
      bearingDegrees == null ? '—' : '${bearingDegrees!.toStringAsFixed(1)}°';

  /// Mata angin delapan arah dalam bahasa Indonesia.
  String get compassPoint =>
      bearingDegrees == null ? '—' : compassPointOf(bearingDegrees!);

  String get distanceLabel => '${_thousands(distanceKm.round())} km';
}

/// Bearing awal dari [location] ke Ka'bah, searah jarum jam dari utara sejati
/// (bukan utara magnetik).
QiblaReading qiblaFor(WorshipLocation location) {
  if (!WorshipLocation.coordinateInRange(
    location.latitude,
    location.longitude,
  )) {
    return const QiblaReading._(
      distanceKm: 0,
      undefinedReason: QiblaUndefinedReason.invalidCoordinates,
    );
  }
  final distance = _distanceKm(location);
  if (distance < undefinedNearKm) {
    return QiblaReading._(
      distanceKm: distance,
      undefinedReason: QiblaUndefinedReason.atLocation,
    );
  }
  if (distance > undefinedFarKm) {
    return QiblaReading._(
      distanceKm: distance,
      undefinedReason: QiblaUndefinedReason.antipode,
    );
  }
  return QiblaReading._(
    distanceKm: distance,
    bearingDegrees: _initialBearingDegrees(location),
  );
}

double _initialBearingDegrees(WorshipLocation location) {
  final lat1 = _radians(location.latitude);
  final lat2 = _radians(kaabaLocation.latitude);
  final dLon = _radians(kaabaLocation.longitude - location.longitude);
  return normalizeDegrees(
    _degrees(
      math.atan2(
        math.sin(dLon),
        math.cos(lat1) * math.tan(lat2) - math.sin(lat1) * math.cos(dLon),
      ),
    ),
  );
}

double _distanceKm(WorshipLocation location) {
  final lat1 = _radians(location.latitude);
  final lat2 = _radians(kaabaLocation.latitude);
  final dLat = lat2 - lat1;
  final dLon = _radians(kaabaLocation.longitude - location.longitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Membawa sudut apa pun ke rentang [0, 360).
double normalizeDegrees(double degrees) {
  final rest = degrees % 360;
  return rest < 0 ? rest + 360 : rest;
}

/// Heading perangkat yang boleh dipakai untuk memutar dial: angka hingga dan
/// bukan status sensor "unreliable" (akurasi negatif pada Android).
bool isUsableHeading(double? headingDegrees, [double? accuracyDegrees]) {
  if (headingDegrees == null || !headingDegrees.isFinite) return false;
  if (accuracyDegrees != null &&
      accuracyDegrees.isFinite &&
      accuracyDegrees < 0) {
    return false;
  }
  return true;
}

/// Kiblat relatif terhadap tepi atas perangkat:
/// `(qiblaBearing - deviceHeading + 360) % 360`.
double relativeQibla({
  required double qiblaBearing,
  required double deviceHeading,
}) => normalizeDegrees(qiblaBearing - deviceHeading);

/// Deviasi besar atau status tidak terkalibrasi: heading masih bisa dipakai
/// bila [isUsableHeading], tetapi UI harus menampilkan panduan kalibrasi.
bool headingNeedsCalibration(double? accuracyDegrees) {
  if (accuracyDegrees == null || !accuracyDegrees.isFinite) return false;
  return accuracyDegrees < 0 || accuracyDegrees >= 15;
}

/// Selisih tanda terpendek dari [from] ke [to]: positif berarti memutar searah
/// jarum jam, hasil selalu dalam (-180, 180].
double alignmentDelta({required double from, required double to}) {
  final rest = (to - from) % 360;
  return rest > 180 ? rest - 360 : rest;
}

const List<String> _compassPoints = [
  'Utara',
  'Timur Laut',
  'Timur',
  'Tenggara',
  'Selatan',
  'Barat Daya',
  'Barat',
  'Barat Laut',
];

String compassPointOf(double degrees) {
  final index = ((normalizeDegrees(degrees) + 22.5) % 360 / 45).floor();
  return _compassPoints[index % 8];
}

/// Petunjuk putar untuk menyamakan dial dengan arah kiblat.
String turnHint(double deltaDegrees) {
  final steps = deltaDegrees.abs() < 0.5 ? 0 : deltaDegrees.abs().round();
  if (steps == 0) return 'Sudah sejajar';
  return 'Putar $steps° ke ${deltaDegrees > 0 ? 'kanan' : 'kiri'}';
}

String _thousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

double _radians(double degrees) => degrees * math.pi / 180;
double _degrees(double radians) => radians * 180 / math.pi;
