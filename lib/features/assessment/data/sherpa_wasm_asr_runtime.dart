import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:web/web.dart' as web;

import '../domain/recitation_audio.dart';
import 'asr_model_provisioner.dart';
import 'asr_model_release.dart';
import 'asr_model_transport_web.dart';
import 'asr_runtime.dart';

/// Adapter Web dari satu antarmuka [AsrRuntime]: sherpa-onnx WASM dengan model
/// Zipformer CTC Abdou/quran-asr-small INT8 di atas CPU.
///
/// Model tidak ikut bundel `flutter_assets`; ia diunduh dari `web/asr/` pada
/// penilaian pertama, diverifikasi SHA-256, lalu disimpan di Cache Storage
/// bernama versi rilis.
class SherpaWasmAsrRuntime implements AsrRuntime {
  SherpaWasmAsrRuntime({AsrModelRelease release = asrWebModelRelease})
    : _release = release;

  /// Pembatas thread untuk model ONNX. WASM build boleh mengabaikannya bila
  /// pthreads tidak aktif, jadi nilai ini hanya permintaan.
  static const _requestedThreads = 2;

  /// Aset bundel bawaan plugin `sherpa_onnx_web` — sumber wrapper ASR JS yang
  /// sudah dievaluasi `loadWasm()`.
  static const _wrapperAsset =
      'packages/sherpa_onnx_web/assets/sherpa-onnx-asr.js';

  /// Penutup eval yang sama dengan deklarasi kelasnya.
  static const _exposeClass = r'''
if (typeof globalThis.OfflineRecognizer === "undefined") {
  globalThis.OfflineRecognizer = OfflineRecognizer;
}
''';

  final AsrModelRelease _release;

  sherpa.OfflineRecognizer? _recognizer;
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
    onProgress?.call(null, 'Memuat runtime WASM…');
    await sherpa.initBindingsAsync();
    await _exposeRecognizerConstructor();

    final provisioner = AsrModelProvisioner(
      transport: AsrModelTransportWeb(_release),
      release: _release,
    );
    final files = await provisioner.ensure(
      onProgress: (fraction, message) => onProgress?.call(fraction, message),
    );
    for (final file in _release.files) {
      final bytes = files[file.name];
      if (bytes == null) {
        throw AsrModelProvisioningException(
          AsrModelFailureKind.integrity,
          'Model ${file.name} tidak tersedia setelah unduhan selesai.',
        );
      }
      _writeToWasmFileSystem(file.name, bytes);
    }

    onProgress?.call(null, 'Menyiapkan engine pengenalan…');
    final recognizer = await sherpa.OfflineRecognizer.createAsync(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          zipformerCtc: sherpa.OfflineZipformerCtcModelConfig(
            model: '/${_release.model.name}',
          ),
          tokens: '/${_release.tokens.name}',
          numThreads: _threadCount,
          provider: 'cpu',
          debug: false,
        ),
      ),
    );
    // Halaman bisa ditutup sementara model masih dimuat; recognizer dibuang
    // agar WASM heap tidak tertinggal.
    if (_disposed) {
      recognizer.free();
      return;
    }
    _recognizer = recognizer;
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
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      recognizer.decode(stream);
      return recognizer.getResult(stream).text.trim();
    } on AsrRecognitionException {
      rethrow;
    } catch (failure) {
      // Nilai mentah (kode status Emscripten) hanya layak masuk log developer;
      // pengguna menerima pesan yang sudah dipetakan.
      developer.log(
        'decode ditolak engine, nilai mentah: $failure',
        name: 'tilawahku.asr',
      );
      throw AsrRecognitionException(describeAsrFailure(failure));
    } finally {
      stream.free();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _recognizer?.free();
    _recognizer = null;
  }

  int get _threadCount {
    final cores = web.window.navigator.hardwareConcurrency;
    if (cores < 1) return 1;
    return cores < _requestedThreads ? cores : _requestedThreads;
  }

  void _writeToWasmFileSystem(String fileName, Uint8List bytes) {
    final module = globalContext.getProperty('Module'.toJS) as JSObject?;
    final fs = module?.getProperty('FS'.toJS) as JSObject?;
    final writeFile = fs?.getProperty('writeFile'.toJS) as JSFunction?;
    if (writeFile == null || fs == null) {
      throw StateError('Runtime WASM tidak menyediakan filesystem model.');
    }
    writeFile.callAsFunction(fs, '/$fileName'.toJS, bytes.toJS);
  }

  /// `sherpa_onnx_web` mendeklarasikan wrapper JS lewat `eval` tidak langsung,
  /// jadi `class OfflineRecognizer` hanya menjadi binding leksikal milik eval
  /// tersebut dan ikut hilang saat eval selesai. Binding Web `sherpa_onnx`
  /// membaca `globalThis`, jadi sumber wrapper dievaluasi ulang sekali di sini
  /// dengan assignment global pada eval yang sama — tanpa vendoring package.
  Future<void> _exposeRecognizerConstructor() async {
    if (globalContext.getProperty('OfflineRecognizer'.toJS) != null) return;
    final eval = globalContext.getProperty('eval'.toJS) as JSFunction?;
    if (eval == null) {
      throw StateError('Runtime WASM tidak dapat dijangkau.');
    }
    final data = await rootBundle.load(_wrapperAsset);
    final source = utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    eval.callAsFunction(null, '$source\n$_exposeClass'.toJS);
    if (globalContext.getProperty('OfflineRecognizer'.toJS) == null) {
      throw StateError('Runtime WASM tidak menyediakan engine pengenalan.');
    }
  }
}
