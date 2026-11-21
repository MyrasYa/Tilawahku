import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'asr_model_release.dart';

enum AsrModelFailureKind { network, integrity, notConfigured }

class AsrModelProvisioningException implements Exception {
  const AsrModelProvisioningException(this.kind, this.message);

  final AsrModelFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Jalur transfer model. Implementasi Web memakai `fetch` + Cache Storage;
/// test memakai memori biasa sehingga kebijakan di [AsrModelProvisioner]
/// teruji tanpa browser.
abstract interface class AsrModelTransport {
  Future<Uint8List?> readCached(AsrModelFile file);
  Future<void> writeCached(AsrModelFile file, Uint8List bytes);
  Future<void> removeCached(AsrModelFile file);
  Stream<Uint8List> download(AsrModelFile file);
}

/// Kebijakan penyedia model: pakai cache bila integritasnya terbukti, buang
/// bila rusak, unduh ulang dengan retry, dan validasi SHA-256 sebelum hasil
/// diserahkan ke runtime.
class AsrModelProvisioner {
  AsrModelProvisioner({
    required AsrModelTransport transport,
    required AsrModelRelease release,
    int maxAttempts = 3,
    Future<void> Function(Duration delay)? sleep,
  }) : _transport = transport,
       _release = release,
       _maxAttempts = maxAttempts,
       _sleep = sleep ?? Future.delayed;

  static const _chunkBytes = 1 << 20;

  /// Unduhan dilaporkan per segmen ini agar UI tidak dibanjiri callback untuk
  /// file puluhan megabyte.
  static const _progressStepBytes = 512 * 1024;

  final AsrModelTransport _transport;
  final AsrModelRelease _release;
  final int _maxAttempts;
  final Future<void> Function(Duration delay) _sleep;

  Future<Map<String, Uint8List>> ensure({
    void Function(double fraction, String message)? onProgress,
  }) async {
    final result = <String, Uint8List>{};
    var completedBytes = 0;
    for (final file in _release.files) {
      result[file.name] = await _ensureFile(
        file,
        (message, receivedBytes) => onProgress?.call(
          ((completedBytes + receivedBytes) / _release.totalBytes).clamp(
            0.0,
            1.0,
          ),
          message,
        ),
      );
      completedBytes += file.byteLength;
    }
    return result;
  }

  Future<Uint8List> _ensureFile(
    AsrModelFile file,
    void Function(String message, int receivedBytes) onProgress,
  ) async {
    onProgress('Memeriksa cache model', 0);
    final cached = await _readCached(file);
    if (cached != null) {
      if (cached.length == file.byteLength &&
          await _digest(cached) == file.sha256Hex) {
        onProgress('Model siap dari cache', file.byteLength);
        return cached;
      }
      // Cache rusak atau tidak lengkap: dibuang lalu diunduh ulang, bukan
      // dipakai setengah jalan.
      await _removeCached(file);
    }

    var lastKind = AsrModelFailureKind.network;
    String? lastDetail;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final downloaded = await _download(file, onProgress, attempt: attempt);
        if (downloaded.bytes.length != file.byteLength ||
            downloaded.digest != file.sha256Hex) {
          lastKind = AsrModelFailureKind.integrity;
          lastDetail =
              'SHA-256 atau ukuran ${downloaded.bytes.length} B tidak cocok '
              'dengan rilis ${_release.version}';
          await _removeCached(file);
        } else {
          await _writeCached(file, downloaded.bytes);
          onProgress('Model siap', file.byteLength);
          return downloaded.bytes;
        }
      } on AsrModelProvisioningException {
        rethrow;
      } catch (error) {
        lastKind = AsrModelFailureKind.network;
        lastDetail = '$error';
        await _removeCached(file);
      }
      if (attempt < _maxAttempts) {
        onProgress(
          'Model gagal dimuat, mengulang ($attempt/${_maxAttempts - 1})',
          0,
        );
        await _sleep(Duration(milliseconds: 500 * attempt));
      }
    }
    throw AsrModelProvisioningException(
      lastKind,
      lastKind == AsrModelFailureKind.integrity
          ? 'Model penilaian tidak lolos pemeriksaan integritas '
                '($lastDetail).'
          : 'Model penilaian gagal diunduh setelah $_maxAttempts percobaan '
                '($lastDetail). Periksa koneksi lalu coba lagi.',
    );
  }

  Future<({Uint8List bytes, String digest})> _download(
    AsrModelFile file,
    void Function(String message, int receivedBytes) onProgress, {
    required int attempt,
  }) async {
    final builder = BytesBuilder(copy: false);
    final sink = _DigestSink();
    final accumulator = sha256.startChunkedConversion(sink);
    onProgress(
      attempt > 1
          ? 'Mengunduh ulang model'
          : 'Mengunduh model (${_mb(file.byteLength)})',
      0,
    );
    var reportedBytes = 0;
    await for (final chunk in _transport.download(file)) {
      builder.add(chunk);
      accumulator.add(chunk);
      if (builder.length - reportedBytes >= _progressStepBytes) {
        reportedBytes = builder.length;
        onProgress(
          'Mengunduh model · ${_mb(builder.length)} dari '
          '${_mb(file.byteLength)}',
          builder.length,
        );
      }
    }
    accumulator.close();
    return (bytes: builder.takeBytes(), digest: sink.value.toString());
  }

  /// Hash dijalankan per 1 MB dengan jeda agar tab Web tidak membeku lama;
  /// nilai yang sama dihasilkan dengan hash sekali jalan di test VM.
  Future<String> _digest(Uint8List bytes) async {
    final sink = _DigestSink();
    final accumulator = sha256.startChunkedConversion(sink);
    for (var offset = 0; offset < bytes.length; offset += _chunkBytes) {
      accumulator.add(
        bytes.sublist(offset, math.min(offset + _chunkBytes, bytes.length)),
      );
      await Future<void>.delayed(Duration.zero);
    }
    accumulator.close();
    return sink.value.toString();
  }

  Future<Uint8List?> _readCached(AsrModelFile file) async {
    try {
      return await _transport.readCached(file);
    } catch (_) {
      await _removeCached(file);
      return null;
    }
  }

  Future<void> _removeCached(AsrModelFile file) async {
    try {
      await _transport.removeCached(file);
    } catch (_) {
      // Cache Storage bisa ditolak browser; penilaian tetap berjalan tanpa
      // cache asalkan bytes hasil unduh terverifikasi.
    }
  }

  Future<void> _writeCached(AsrModelFile file, Uint8List bytes) async {
    try {
      await _transport.writeCached(file, bytes);
    } catch (_) {
      // Gagal menyimpan cache bukan kegagalan penilaian.
    }
  }

  static String _mb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
