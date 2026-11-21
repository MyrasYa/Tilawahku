import 'package:flutter/foundation.dart';

import '../data/asr_runtime.dart';
import '../data/assessment_lexicon.dart';
import '../data/recitation_recorder.dart';
import '../domain/arabic_comparison.dart';
import '../domain/assessment_attempt.dart';

enum AssessmentMode {
  latihan('Mode Latihan'),
  setoran('Mode Setoran');

  const AssessmentMode(this.label);

  final String label;
}

enum AssessmentPhase {
  unavailable,
  idle,
  preparing,
  recording,
  processing,
  scored,
  failed,
}

class RecitationAssessmentController extends ChangeNotifier {
  RecitationAssessmentController({
    required this.runtime,
    required RecitationCapture Function() createCapture,
    Future<Map<String, String>> Function() loadSpellingMap =
        loadAssessmentSpellingMap,
  }) : _createCapture = createCapture,
       _loadSpellingMap = loadSpellingMap {
    if (runtime == null) _phase = AssessmentPhase.unavailable;
  }

  final AsrRuntime? runtime;
  final RecitationCapture Function() _createCapture;
  final Future<Map<String, String>> Function() _loadSpellingMap;

  static const _belowMinimumNote =
      'Rekaman terlalu singkat untuk dikenali mesin. Baca satu potong ayat '
      'lalu rekam ulang.';

  RecitationCapture? _capture;
  AssessmentPhase _phase = AssessmentPhase.idle;
  AssessmentMode _mode = AssessmentMode.latihan;
  AssessmentAttempt? _attempt;
  String? _message;
  String? _progressMessage;
  double? _progressFraction;
  bool _runtimePrepared = false;
  bool _disposed = false;

  /// Naik setiap kali rekaman dibatalkan (ayat berganti, mode berganti, halaman
  /// ditutup). Persiapan dan inferensi yang sudah melewati `await` wajib
  /// memeriksanya; tanpa ini rekaman ayat lama bisa mulai sendiri, atau hasil
  /// ayat lama muncul sebagai hasil ayat berikutnya.
  int _generation = 0;

  bool _isStale(int generation) => _disposed || generation != _generation;

  Future<void> _release = Future<void>.value();

  AssessmentMode get mode => _mode;

  AssessmentPhase get phase => _phase;

  AssessmentAttempt? get attempt => _attempt;

  String? get message => _message;

  String? get progressMessage => _progressMessage;

  /// Progres unduhan model; `null` untuk tahap tanpa bobot persentase.
  double? get progressFraction => _progressFraction;

  /// Selesai melepas mikrofon dan runtime; dipakai test lifecycle.
  Future<void> get released => _release;

  bool get canRecord =>
      runtime != null &&
      (_phase == AssessmentPhase.idle ||
          _phase == AssessmentPhase.scored ||
          _phase == AssessmentPhase.failed);

  bool get isRecording => _phase == AssessmentPhase.recording;

  bool get isWorking =>
      _phase == AssessmentPhase.preparing ||
      _phase == AssessmentPhase.processing;

  /// Mode Setoran menutup teks selama rekaman dan pemprosesan berjalan;
  /// hasil penilaian selalu menampilkan kembali teks targetnya.
  bool get hidesTargetText =>
      _mode == AssessmentMode.setoran &&
      (_phase == AssessmentPhase.recording ||
          _phase == AssessmentPhase.processing);

  Future<void> setMode(AssessmentMode next) async {
    if (_mode == next || _disposed) return;
    _mode = next;
    _attempt = null;
    _message = null;
    await _returnToIdle(discardRecording: true);
  }

  Future<void> startRecording() async {
    final engine = runtime;
    if (engine == null || !canRecord || _disposed) return;
    final generation = _generation;
    _attempt = null;
    _message = null;
    _phase = AssessmentPhase.preparing;
    notifyListeners();
    try {
      if (!_runtimePrepared) {
        await engine.prepare(
          onProgress: (fraction, message) {
            if (_isStale(generation)) return;
            _progressFraction = fraction;
            _progressMessage = fraction == null
                ? message
                : '${(fraction * 100).toStringAsFixed(0)} % · $message';
            notifyListeners();
          },
        );
        _runtimePrepared = true;
      }
      // Unduhan model bisa puluhan detik: bila ayat berganti atau halaman
      // ditutup selama itu, mikrofon tidak boleh dibuka untuk ayat yang salah.
      if (_isStale(generation)) return;
      _progressFraction = null;
      _progressMessage = null;
      final capture = _capture ??= _createCapture();
      await capture.start();
      if (_isStale(generation)) {
        // Saat `dispose()` berjalan, mikrofon sudah dilepas oleh
        // `_releaseResources()`; hanya pembatalan manual yang perlu ditutup.
        if (!_disposed) await capture.cancel();
        return;
      }
      _phase = AssessmentPhase.recording;
    } on RecitationCaptureException catch (error) {
      if (_isStale(generation)) return;
      await _fail(error.message);
    } catch (error) {
      if (_isStale(generation)) return;
      await _fail('Mesin penilaian gagal disiapkan: ${_safeDetail(error)}');
    }
    notifyListeners();
  }

  Future<void> stopAndScore(String targetText) async {
    final engine = runtime;
    final capture = _capture;
    if (engine == null || capture == null || !isRecording || _disposed) return;
    final generation = _generation;
    _phase = AssessmentPhase.processing;
    notifyListeners();
    try {
      final audio = await capture.stop();
      if (_isStale(generation)) return;
      // Audio di bawah lantai engine tidak pernah dikenali: graph ONNX gagal di
      // tengah sebelum menghasilkan frame, jadi vonisnya ditetapkan di sini.
      final belowMinimum = !audio.meetsAsrMinimum;
      final transcript = belowMinimum
          ? ''
          : (await engine.recognize(audio)).trim();
      final comparison = compareArabicWords(
        targetText,
        transcript,
        spellingMap: await _loadSpellingMap(),
      );
      // Inferensi 1–10 detik: hasil ayat yang sudah ditinggalkan tidak boleh
      // dipublikasikan sebagai penilaian ayat berikutnya.
      if (_isStale(generation)) return;
      _attempt = AssessmentAttempt(
        transcript: transcript,
        comparison: comparison,
        audioSeconds: audio.durationSeconds,
        note: belowMinimum ? _belowMinimumNote : null,
      );
      _message = null;
      _phase = AssessmentPhase.scored;
    } on RecitationCaptureException catch (error) {
      if (_isStale(generation)) return;
      await _fail(error.message);
    } on AsrRecognitionException catch (error) {
      if (_isStale(generation)) return;
      await _fail(error.message);
    } catch (error) {
      if (_isStale(generation)) return;
      await _fail('Rekaman tidak dapat dinilai: ${_safeDetail(error)}');
    }
    notifyListeners();
  }

  /// Ayat berganti atau pengguna membatalkan: hasil lama dibuang dan
  /// rekaman dihentikan agar tidak terhitung di ayat berikutnya.
  Future<void> discardRecording() async {
    _attempt = null;
    _message = null;
    await _returnToIdle(discardRecording: true);
  }

  Future<void> _returnToIdle({required bool discardRecording}) async {
    final capture = _capture;
    final wasCapturing =
        _phase == AssessmentPhase.recording ||
        _phase == AssessmentPhase.preparing;
    _generation++;
    _progressFraction = null;
    _progressMessage = null;
    _phase = runtime == null
        ? AssessmentPhase.unavailable
        : AssessmentPhase.idle;
    notifyListeners();
    if (discardRecording && wasCapturing && capture != null) {
      await capture.cancel();
    }
  }

  Future<void> _fail(String message) async {
    _message = message;
    _phase = AssessmentPhase.failed;
    _progressMessage = null;
    _progressFraction = null;
    notifyListeners();
  }

  /// Nilai yang bukan teks (mis. kode status dari glue platform) tidak boleh
  /// muncul apa adanya di kartu penilaian.
  static String _safeDetail(Object error) =>
      error is num ? 'kesalahan mesin penilaian' : '$error';

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _release = _releaseResources();
    super.dispose();
  }

  Future<void> _releaseResources() async {
    final capture = _capture;
    _capture = null;
    if (capture != null) await capture.dispose();
    runtime?.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
