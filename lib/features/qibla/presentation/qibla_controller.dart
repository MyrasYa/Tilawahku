import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../prayer/data/device_location.dart';
import '../../prayer/domain/prayer_models.dart';
import '../../prayer/presentation/location_selection.dart';
import '../data/qibla_heading_source.dart';
import '../data/qibla_location_store.dart';
import '../domain/qibla_direction.dart';

enum QiblaLoadState { loading, ready, needsLocation }

/// Sumber heading yang sedang dipakai untuk memutar dial.
enum QiblaHeadingMode { live, manual }

/// State layar kiblat: lokasi bersama, bearing ke Ka'bah, dan heading perangkat
/// atau dial manual. Perhitungan kiblat tetap murni matematika.
class QiblaController extends ChangeNotifier implements LocationSelection {
  QiblaController({
    QiblaLocationStore? store,
    QiblaHeadingSource? headingSource,
    this.headingStaleAfter = const Duration(seconds: 3),
  }) : _store = store ?? QiblaLocationStore(),
       _headingSource = headingSource ?? createQiblaHeadingSource();

  final QiblaLocationStore _store;
  final QiblaHeadingSource _headingSource;

  /// Bila tidak ada sampel sah selama jangka ini, heading live dianggap basi.
  final Duration headingStaleAfter;

  QiblaLoadState state = QiblaLoadState.loading;
  @override
  List<WorshipLocation> cities = const [];
  WorshipLocation? location;
  QiblaReading? reading;
  @override
  String? locationMessage;
  String? errorMessage;
  @override
  bool busy = false;

  /// Arah tepi atas ponsel terhadap utara. Di mode live diisi sensor; di mode
  /// manual diisi geseran pengguna. Bukan heading palsu.
  double dialDegrees = 0;

  QiblaHeadingMode headingMode = QiblaHeadingMode.manual;
  bool sensorsAvailable = false;
  QiblaHeadingSample? lastUsableHeading;
  String? compassMessage;
  bool headingUnreliable = false;

  StreamSubscription<QiblaHeadingSample>? _headingSub;
  Timer? _staleTimer;
  bool _headingPaused = false;
  bool _disposed = false;

  @override
  WorshipLocation? get selectedLocation => location;

  bool get hasReading => reading?.hasBearing ?? false;

  bool get isLiveCompass => headingMode == QiblaHeadingMode.live;

  /// Sudut penanda Ka'bah pada dial, diukur dari tepi atas.
  double get markerDegrees {
    final bearing = reading?.bearingDegrees;
    if (bearing == null) return 0;
    return relativeQibla(qiblaBearing: bearing, deviceHeading: dialDegrees);
  }

  /// Derajat yang masih harus diputar agar sejajar: positif = ke kanan.
  double get turnDelta {
    final bearing = reading?.bearingDegrees;
    return bearing == null ? 0 : alignmentDelta(from: dialDegrees, to: bearing);
  }

  String get turnHintLabel => turnHint(turnDelta);

  String get headingModeLabel =>
      isLiveCompass ? 'Kompas perangkat' : 'Dial manual';

  String? get deviceHeadingLabel {
    if (isLiveCompass) {
      return '${dialDegrees.toStringAsFixed(1)}° dari utara';
    }
    return null;
  }

  Future<void> start() async {
    try {
      cities = await _store.loadCities();
    } on Object {
      cities = const [];
    }
    try {
      location = await _store.loadSavedLocation();
    } on Object catch (error) {
      errorMessage = 'Lokasi tersimpan tidak dapat dibaca: $error';
      location = null;
    }
    _recompute();
    _notify();
    await _syncHeadingSubscription();
  }

  /// Dipanggil layar saat aplikasi ke latar belakang.
  Future<void> pauseHeading() async {
    _headingPaused = true;
    await _cancelHeading();
    if (headingMode == QiblaHeadingMode.live) {
      headingMode = QiblaHeadingMode.manual;
      compassMessage =
          'Kompas dijeda. Dial manual tidak mengikuti arah fisik perangkat.';
      _notify();
    }
  }

  /// Dipanggil layar saat aplikasi kembali aktif.
  Future<void> resumeHeading() async {
    _headingPaused = false;
    await _syncHeadingSubscription();
  }

  @override
  Future<void> useDeviceLocation() async {
    busy = true;
    locationMessage = null;
    _notify();
    try {
      final located = await _store.locateDevice();
      await _applyLocation(located);
    } on LocationFailure catch (failure) {
      locationMessage = '${failure.message} ${failure.suggestion}';
    } on Object catch (error) {
      locationMessage = 'Lokasi gagal diambil: $error';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  Future<void> selectCity(WorshipLocation city) => _applyLocation(
    WorshipLocation(
      name: city.name,
      latitude: city.latitude,
      longitude: city.longitude,
      source: LocationSource.saved,
      timezoneId: city.timezoneId,
      country: city.country,
    ),
  );

  @override
  Future<void> enterCoordinates({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    if (!WorshipLocation.coordinateInRange(latitude, longitude)) {
      locationMessage = 'Koordinat harus dalam rentang -90..90 dan -180..180.';
      _notify();
      return;
    }
    locationMessage = null;
    await _applyLocation(
      WorshipLocation(
        name: name.trim().isEmpty ? 'Lokasi manual' : name.trim(),
        latitude: latitude,
        longitude: longitude,
        source: LocationSource.manual,
      ),
    );
  }

  /// Memutar dial dari isyarat geser; diabaikan saat kompas live.
  void rotateDial(double deltaDegrees) {
    if (isLiveCompass) return;
    dialDegrees = normalizeDegrees(dialDegrees + deltaDegrees);
    _notify();
  }

  void setDial(double degrees) {
    if (isLiveCompass) return;
    dialDegrees = normalizeDegrees(degrees);
    _notify();
  }

  void resetDial() {
    if (isLiveCompass) return;
    dialDegrees = 0;
    _notify();
  }

  Future<void> _applyLocation(WorshipLocation next) async {
    location = next;
    errorMessage = null;
    try {
      await _store.saveLocation(next);
    } on Object catch (error) {
      errorMessage = 'Lokasi tidak dapat disimpan: $error';
    }
    _recompute();
    _notify();
    await _syncHeadingSubscription();
  }

  void _recompute() {
    final current = location;
    if (current == null) {
      state = QiblaLoadState.needsLocation;
      reading = null;
      return;
    }
    reading = qiblaFor(current);
    dialDegrees = normalizeDegrees(dialDegrees);
    state = QiblaLoadState.ready;
  }

  Future<void> _syncHeadingSubscription() async {
    if (_disposed || _headingPaused || state != QiblaLoadState.ready) {
      await _cancelHeading();
      _setManualFallback(
        sensorsAvailable
            ? 'Kompas dijeda. Dial manual tidak mengikuti arah fisik perangkat.'
            : _manualFallbackMessage(),
      );
      _notify();
      return;
    }
    if (_headingSub != null) return;

    try {
      sensorsAvailable = await _headingSource.hasSensors();
    } on Object {
      sensorsAvailable = false;
    }
    if (!sensorsAvailable) {
      _setManualFallback(_manualFallbackMessage());
      _notify();
      return;
    }

    compassMessage =
        'Menunggu bacaan kompas. Bila tidak muncul, gunakan dial manual.';
    headingMode = QiblaHeadingMode.manual;
    headingUnreliable = false;
    lastUsableHeading = null;
    _notify();

    try {
      _headingSub = _headingSource.watch().listen(
        _onHeading,
        onError: (_) => _onHeadingError(),
      );
    } on Object {
      sensorsAvailable = false;
      _setManualFallback(
        'Kompas perangkat tidak dapat dibaca. Dial diputar manual dan tidak '
        'mengikuti arah fisik perangkat.',
      );
      _notify();
    }
  }

  void _onHeading(QiblaHeadingSample sample) {
    if (_disposed) return;
    if (!sample.isUsable) {
      headingUnreliable = true;
      compassMessage =
          'Bacaan kompas tidak dipakai karena tidak sah atau tidak terkalibrasi. '
          'Jauhkan dari magnet dan gerakkan perangkat membentuk angka 8, atau '
          'pakai dial manual.';
      _armStaleTimer();
      _notify();
      return;
    }

    lastUsableHeading = sample;
    headingMode = QiblaHeadingMode.live;
    dialDegrees = normalizeDegrees(sample.headingDegrees!);
    headingUnreliable = sample.needsCalibration;
    compassMessage = headingUnreliable
        ? 'Ketelitian kompas rendah. Jauhkan dari magnet, casing logam, atau '
              'pengisi daya, lalu gerakkan perangkat membentuk angka 8.'
        : null;
    _armStaleTimer();
    _notify();
  }

  void _onHeadingError() {
    if (_disposed) return;
    unawaited(_cancelHeading());
    sensorsAvailable = false;
    _setManualFallback(
      'Kompas perangkat tidak dapat dibaca. Dial diputar manual dan tidak '
      'mengikuti arah fisik perangkat.',
    );
    _notify();
  }

  void _armStaleTimer() {
    _staleTimer?.cancel();
    if (headingStaleAfter <= Duration.zero) return;
    _staleTimer = Timer(headingStaleAfter, _onHeadingStale);
  }

  void _onHeadingStale() {
    if (_disposed || headingMode != QiblaHeadingMode.live) return;
    headingMode = QiblaHeadingMode.manual;
    headingUnreliable = true;
    compassMessage =
        'Bacaan kompas terhenti. Dial manual tidak mengikuti arah fisik '
        'perangkat sampai sensor kembali aktif.';
    _notify();
  }

  void _setManualFallback(String message) {
    headingMode = QiblaHeadingMode.manual;
    headingUnreliable = false;
    lastUsableHeading = null;
    compassMessage = message;
  }

  String _manualFallbackMessage() {
    if (kIsWeb) {
      return 'Peramban tidak menyediakan kompas yang andal. Putar dial sampai '
          'penanda Ka\'bah di ujung atas; acuan sudut adalah utara sejati, '
          'bukan heading fisik perangkat.';
    }
    return 'Kompas perangkat tidak tersedia. Putar dial sampai penanda Ka\'bah '
        'di ujung atas; dial ini tidak mengikuti arah fisik perangkat.';
  }

  Future<void> _cancelHeading() async {
    _staleTimer?.cancel();
    _staleTimer = null;
    await _headingSub?.cancel();
    _headingSub = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_cancelHeading());
    super.dispose();
  }
}
