import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../domain/recitation_audio.dart';

enum RecitationCaptureFailure {
  permissionDenied,
  noMicrophone,
  unsupportedFormat,
  emptyRecording,
  interrupted,
}

class RecitationCaptureException implements Exception {
  const RecitationCaptureException(this.failure, this.message);

  final RecitationCaptureFailure failure;
  final String message;

  @override
  String toString() => message;
}

abstract interface class RecitationCapture {
  Future<void> start();

  Future<RecitationAudio> stop();

  Future<void> cancel();

  Future<void> dispose();
}

/// Memastikan audio yang benar-benar dikirim platform, bukan hanya label
/// format. Mengembalikan `null` bila audio layak masuk engine ASR.
RecitationCaptureException? validateDeliveredFormat({
  required RecitationAudio audio,
  required double elapsedSeconds,
  required int byteLength,
  RecordConfig? reportedConfig,
}) {
  if (byteLength < 2 || audio.samples.isEmpty) {
    return const RecitationCaptureException(
      RecitationCaptureFailure.emptyRecording,
      'Rekaman kosong atau terlalu singkat untuk dinilai.',
    );
  }
  if (reportedConfig != null &&
      (reportedConfig.sampleRate != asrSampleRate ||
          reportedConfig.numChannels != 1)) {
    return RecitationCaptureException(
      RecitationCaptureFailure.unsupportedFormat,
      'Perangkat mengirim audio ${reportedConfig.sampleRate} Hz · '
      '${reportedConfig.numChannels} kanal, bukan $asrSampleRate Hz mono yang '
      'dibutuhkan engine ASR.',
    );
  }
  if (elapsedSeconds < 1) return null;
  final ratio = audio.durationSeconds / elapsedSeconds;
  if (ratio > 1.5) {
    return RecitationCaptureException(
      RecitationCaptureFailure.unsupportedFormat,
      'Jumlah sampel ${(ratio * 100).toStringAsFixed(0)} % dari durasi rekam, '
      'jadi laju sampel tidak dapat dipercaya sebagai $asrSampleRate Hz.',
    );
  }
  if (ratio < 0.6) {
    return const RecitationCaptureException(
      RecitationCaptureFailure.interrupted,
      'Rekaman terputus sehingga tidak dapat dinilai.',
    );
  }
  return null;
}

/// Rekaman hanya disimpan di memori sampai dinilai, lalu dibuang.
class MicrophoneCapture implements RecitationCapture {
  MicrophoneCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: asrSampleRate,
    numChannels: 1,
    echoCancel: false,
    noiseSuppress: false,
    autoGain: false,
  );

  final AudioRecorder _recorder;

  BytesBuilder? _pcm;
  StreamSubscription<Uint8List>? _subscription;
  Stopwatch? _clock;
  Object? _streamError;
  RecordConfig? _reportedConfig;

  @override
  Future<void> start() async {
    if (_pcm != null) {
      throw const RecitationCaptureException(
        RecitationCaptureFailure.interrupted,
        'Perekaman sudah berjalan.',
      );
    }
    if (!await _recorder.hasPermission()) {
      throw const RecitationCaptureException(
        RecitationCaptureFailure.permissionDenied,
        'Izin mikrofon belum diberikan sehingga bacaan tidak dapat dinilai.',
      );
    }
    if (!await _hasInputDevice()) {
      throw const RecitationCaptureException(
        RecitationCaptureFailure.noMicrophone,
        'Tidak ada mikrofon yang tersedia untuk menilai bacaan.',
      );
    }

    final pcm = BytesBuilder();
    final clock = Stopwatch()..start();
    _streamError = null;
    _reportedConfig = null;
    try {
      await _recorder.setOnConfigChanged((config) {
        _reportedConfig = config;
      });
      final stream = await _recorder.startStream(_config);
      _subscription = stream.listen(
        pcm.add,
        onError: (Object error, StackTrace stackTrace) {
          _streamError = error;
        },
      );
      _pcm = pcm;
      _clock = clock;
    } catch (error) {
      await _reset();
      throw RecitationCaptureException(
        RecitationCaptureFailure.interrupted,
        'Mikrofon tidak dapat dimulai: $error',
      );
    }
  }

  @override
  Future<RecitationAudio> stop() async {
    final pcm = _pcm;
    final clock = _clock;
    if (pcm == null || clock == null) {
      throw const RecitationCaptureException(
        RecitationCaptureFailure.interrupted,
        'Tidak ada rekaman yang berjalan.',
      );
    }
    try {
      await _recorder.stop();
      await _subscription?.cancel();
      final error = _streamError;
      if (error != null) {
        throw RecitationCaptureException(
          RecitationCaptureFailure.interrupted,
          'Perekaman terputus: $error',
        );
      }
      final bytes = pcm.takeBytes();
      final audio = RecitationAudio.fromPcm16(bytes);
      final problem = validateDeliveredFormat(
        audio: audio,
        elapsedSeconds: clock.elapsedMilliseconds / 1000,
        byteLength: bytes.lengthInBytes,
        reportedConfig: _reportedConfig,
      );
      if (problem != null) throw problem;
      return audio;
    } finally {
      await _reset();
    }
  }

  @override
  Future<void> cancel() async {
    if (_pcm == null) return;
    try {
      await _recorder.stop();
    } finally {
      await _reset();
    }
  }

  @override
  Future<void> dispose() async {
    await _reset();
    await _recorder.dispose();
  }

  Future<bool> _hasInputDevice() async {
    try {
      return (await _recorder.listInputDevices()).isNotEmpty;
    } catch (_) {
      // Sebagian platform tidak mengembalikan daftar perangkat; biarkan
      // perekaman tetap dicoba agar pengguna tidak terkunci.
      return true;
    }
  }

  Future<void> _reset() async {
    _pcm = null;
    _clock = null;
    _streamError = null;
    _reportedConfig = null;
    await _recorder.setOnConfigChanged(null);
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
