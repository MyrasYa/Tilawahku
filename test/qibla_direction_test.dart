import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';
import 'package:tilawahku/features/qibla/domain/qibla_direction.dart';

/// Angka AlAdhan `/v1/qibla` diambil 2026-11-21. Selisih terhadap rumus
/// lingkaran besar di bawah 0,001°.
void main() {
  group('qiblaFor', () {
    test('Jakarta cocok dengan AlAdhan sampai < 0,001°', () {
      final reading = qiblaFor(_city('Jakarta', -6.175, 106.827));
      expect(reading.hasBearing, isTrue);
      expect(reading.bearingDegrees, closeTo(295.1460159830117, 0.001));
      expect(reading.distanceKm, closeTo(7916.668, 1));
      expect(reading.bearingLabel, '295.1°');
      expect(reading.compassPoint, 'Barat Laut');
      expect(reading.distanceLabel, '7.917 km');
    });

    test('enam kota lain tetap di bawah 0,001° dari AlAdhan', () {
      final cases = <(WorshipLocation, double)>[
        (_city('Bandung', -6.9147, 107.6098), 295.1688414325397),
        (_city('Madinah', 24.4672, 39.6111), 176.23589894082676),
        (_city('London', 51.5074, -0.1278), 118.98724251452296),
        (_city('New York', 40.7128, -74.006), 58.481712034206865),
        (_city('Sydney', -33.8688, 151.2093), 277.499589412883),
        (_city('Cape Town', -33.9249, 18.4241), 23.35250070951438),
      ];
      for (final (location, expected) in cases) {
        final reading = qiblaFor(location);
        expect(
          reading.bearingDegrees,
          closeTo(expected, 0.001),
          reason: location.name,
        );
      }
    });

    test('koordinat di Ka\'bah tidak punya satu arah', () {
      final reading = qiblaFor(kaabaLocation);
      expect(reading.hasBearing, isFalse);
      expect(reading.undefinedReason, QiblaUndefinedReason.atLocation);
      expect(reading.distanceKm, closeTo(0, 0.01));
      expect(reading.bearingLabel, '—');
    });

    test('antipod Ka\'bah ditandai tidak terdefinisi', () {
      final reading = qiblaFor(_city('Antipod Ka\'bah', -21.4225, -140.1738));
      expect(reading.hasBearing, isFalse);
      expect(reading.undefinedReason, QiblaUndefinedReason.antipode);
      expect(reading.distanceKm, greaterThan(undefinedFarKm));
    });

    test('lintang atau bujur di luar rentang ditolak', () {
      expect(
        qiblaFor(_city('Lintang rusak', 91, 0)).undefinedReason,
        QiblaUndefinedReason.invalidCoordinates,
      );
      expect(
        qiblaFor(_city('Bujur rusak', 0, 181)).undefinedReason,
        QiblaUndefinedReason.invalidCoordinates,
      );
    });

    test('kutub utara dan selatan tetap punya bearing 0–360', () {
      final north = qiblaFor(_city('Kutub Utara', 90, 0));
      final south = qiblaFor(_city('Kutub Selatan', -90, 0));
      expect(north.bearingDegrees, closeTo(140.1738, 0.001));
      expect(south.bearingDegrees, closeTo(39.8262, 0.001));
      expect(north.hasBearing, isTrue);
      expect(south.hasBearing, isTrue);
    });
  });

  group('normalizeDegrees', () {
    test('membawa sudut ke [0, 360)', () {
      expect(normalizeDegrees(0), 0);
      expect(normalizeDegrees(359.9), closeTo(359.9, 1e-9));
      expect(normalizeDegrees(360), 0);
      expect(normalizeDegrees(361), 1);
      expect(normalizeDegrees(-10), 350);
      expect(normalizeDegrees(-360), 0);
      expect(normalizeDegrees(720), 0);
    });
  });

  group('relativeQibla', () {
    test('mengikuti (bearing - heading + 360) % 360', () {
      expect(
        relativeQibla(qiblaBearing: 295.146, deviceHeading: 10),
        closeTo(285.146, 1e-9),
      );
      expect(
        relativeQibla(qiblaBearing: 10, deviceHeading: 350),
        closeTo(20, 1e-9),
      );
      expect(relativeQibla(qiblaBearing: 0, deviceHeading: 0), 0);
    });
  });

  group('heading usability', () {
    test('null, non-finite, dan akurasi negatif tidak dipakai', () {
      expect(isUsableHeading(null), isFalse);
      expect(isUsableHeading(double.nan), isFalse);
      expect(isUsableHeading(double.infinity), isFalse);
      expect(isUsableHeading(12, -1), isFalse);
      expect(isUsableHeading(12, 8), isTrue);
    });

    test('deviasi besar atau status negatif meminta kalibrasi', () {
      expect(headingNeedsCalibration(null), isFalse);
      expect(headingNeedsCalibration(14.9), isFalse);
      expect(headingNeedsCalibration(15), isTrue);
      expect(headingNeedsCalibration(-1), isTrue);
    });
  });

  group('alignmentDelta dan turnHint', () {
    test('selisih terpendek tetap dalam (-180, 180]', () {
      expect(alignmentDelta(from: 0, to: 10), 10);
      expect(alignmentDelta(from: 350, to: 10), 20);
      expect(alignmentDelta(from: 10, to: 350), -20);
      expect(alignmentDelta(from: 0, to: 180), 180);
    });

    test('petunjuk putar memakai kanan/kiri, bukan heading palsu', () {
      expect(turnHint(0), 'Sudah sejajar');
      expect(turnHint(0.4), 'Sudah sejajar');
      expect(turnHint(12.4), 'Putar 12° ke kanan');
      expect(turnHint(-5), 'Putar 5° ke kiri');
    });
  });
}

WorshipLocation _city(String name, double latitude, double longitude) =>
    WorshipLocation(
      name: name,
      latitude: latitude,
      longitude: longitude,
      source: LocationSource.saved,
    );
