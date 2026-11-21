import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../domain/recitation_audio.dart';
import 'asr_model_provisioner.dart';
import 'asr_model_release.dart';
import 'asr_model_transport_file.dart';
import 'asr_runtime.dart';

/// Path berkas model yang sudah lolos verifikasi SHA-256.
typedef AsrModelPaths = ({String modelPath, String tokensPath});

/// Recognizer native di balik seam supaya adapter teruji tanpa pustaka `.so`.
abstract interface class NativeAsrRecognizer {
  String recognize(RecitationAudio audio);

  void dispose();
}

typedef NativeAsrRecognizerFactory =
    Future<NativeAsrRecognizer> Function(AsrModelPaths paths, int numThreads);

/// Basis URL model dari konfigurasi build:
/// `flutter run --dart-define=ASR_MODEL_BASE_URL=https://host/`. Sengaja tidak
/// ada nilai bawaan; tanpa konfigurasi model hanya dilayani dari cache.
const asrModelBaseUrlConfig = String.fromEnvironment('ASR_MODEL_BASE_URL');

/// Adapter Android dari satu antarmuka [AsrRuntime]: sherpa-onnx Native FFI
/// dengan model Zipformer CTC Abdou/quran-asr-small INT8 di atas CPU.
///
/// Berkas `.so` diambil dari APK (arm64-v8a / armeabi-v7a) oleh
/// `DynamicLibrary.open('libsherpa-onnx-c-api.so')`; model diunduh ke
/// direktori dukungan aplikasi karena jalur native hanya membaca path berkas.
class SherpaNativeAsrRuntime implements AsrRuntime {
  SherpaNativeAsrRuntime({
    AsrModelRelease release = asrWebModelRelease,
    Uri? baseUrl,
    Directory? directory,
    NativeAsrRecognizerFactory? recognizerFactory,
  }) : _release = release,
       _baseUrl = baseUrl ?? _configuredBaseUrl(),
       _directoryOverride = directory,
       _factory = recognizerFactory ?? _sherpaNativeRecognizer;

  static const _requestedThreads = 2;

  final AsrModelRelease _release;
  final Uri? _baseUrl;
  final Directory? _directoryOverride;
  final NativeAsrRecognizerFactory _factory;

  NativeAsrRecognizer? _recognizer;
  Future<void>? _preparing;
  bool _disposed = false;

  @override
  Future<void> prepare({AsrProgress? onProgress}) async {
    if (_recognizer != null) return;
    final pending = _preparing;
    if (pending != null) return pending;
    final future = _prepare(onProgress);
    _preparing = future;
    try {
      await future;
    } finally {
      if (identical(_preparing, future)) _preparing = null;
    }
  }

  Future<void> _prepare(AsrProgress? onProgress) async {
    final directory =
        _directoryOverride ??
        Directory('${(await getApplicationSupportDirectory()).path}/asr');
    final transport = AsrModelTransportFile(
      release: _release,
      directory: directory,
      baseUrl: _baseUrl,
    );
    try {
      final files =
          await AsrModelProvisioner(
            transport: transport,
            release: _release,
          ).ensure(
            onProgress: (fraction, message) =>
                onProgress?.call(fraction, message),
          );

      // Menulis cache bisa gagal diam-diam (penyimpanan penuh) sementara
      // provisioner menganggapnya tidak fatal; di sini berkasnya wajib ada
      // karena engine native membaca langsung dari sistem berkas.
      for (final file in _release.files) {
        if (files[file.name] == null) {
          throw AsrModelProvisioningException(
            AsrModelFailureKind.integrity,
            'Model ${file.name} tidak tersedia setelah unduhan selesai.',
          );
        }
        final entry = File('${directory.path}/${file.name}');
        if (!entry.existsSync() || entry.lengthSync() != file.byteLength) {
          throw AsrModelProvisioningException(
            AsrModelFailureKind.integrity,
            'Model ${file.name} tidak tersimpan utuh di penyimpanan aplikasi. '
            'Sisakan ruang lalu coba lagi.',
          );
        }
      }

      onProgress?.call(null, 'Memuat engine pengenalan…');
      final paths = (
        modelPath: '${directory.path}/${_release.model.name}',
        tokensPath: '${directory.path}/${_release.tokens.name}',
      );
      final recognizer = await _factory(paths, _threadCount);
      // Halaman bisa ditutup sementara model masih dimuat; recognizer dibuang
      // agar pustaka native tidak tertinggal di memori proses.
      if (_disposed) {
        recognizer.dispose();
        return;
      }
      _recognizer = recognizer;
    } finally {
      transport.close();
    }
  }

  @override
  Future<String> recognize(RecitationAudio audio) async {
    final recognizer = _recognizer;
    if (recognizer == null) {
      throw StateError('Model penilaian belum siap.');
    }
    if (audio.sampleRate != asrSampleRate) {
      throw StateError(
        'Audio harus $asrSampleRate Hz, diterima ${audio.sampleRate} Hz.',
      );
    }
    if (audio.samples.isEmpty) {
      throw StateError('Rekaman tidak berisi audio.');
    }
    return recognizer.recognize(audio);
  }

  @override
  void dispose() {
    _disposed = true;
    _recognizer?.dispose();
    _recognizer = null;
  }

  int get _threadCount {
    final cores = Platform.numberOfProcessors;
    if (cores < 1) return 1;
    return cores < _requestedThreads ? cores : _requestedThreads;
  }

  static Uri? _configuredBaseUrl() {
    final value = asrModelBaseUrlConfig;
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return null;
    // Tanpa '/' di akhir, `Uri.base.resolve` memperlakukannya sebagai nama
    // berkas, bukan direktori.
    return uri.path.endsWith('/') ? uri : Uri.parse('$uri/');
  }
}

/// Implementasi nyata [NativeAsrRecognizer] di atas bindings sherpa-onnx.
class SherpaNativeRecognizer implements NativeAsrRecognizer {
  SherpaNativeRecognizer._(this._recognizer);

  static Future<SherpaNativeRecognizer> create(
    AsrModelPaths paths,
    int numThreads,
  ) async {
    // Bindings berlaku per isolate; createAsync memuat model di isolate
    // tersendiri, jadi isolate pemanggil juga harus menginit sebelum
    // createStream/decode/getResult dipakai.
    sherpa.initBindings();
    final recognizer = await sherpa.OfflineRecognizer.createAsync(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          zipformerCtc: sherpa.OfflineZipformerCtcModelConfig(
            model: paths.modelPath,
          ),
          tokens: paths.tokensPath,
          numThreads: numThreads,
          provider: 'cpu',
          debug: false,
        ),
      ),
    );
    return SherpaNativeRecognizer._(recognizer);
  }

  final sherpa.OfflineRecognizer _recognizer;

  @override
  String recognize(RecitationAudio audio) {
    final stream = _recognizer.createStream();
    try {
      stream.acceptWaveform(
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      _recognizer.decode(stream);
      return _recognizer.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  @override
  void dispose() => _recognizer.free();
}

Future<NativeAsrRecognizer> _sherpaNativeRecognizer(
  AsrModelPaths paths,
  int numThreads,
) => SherpaNativeRecognizer.create(paths, numThreads);
