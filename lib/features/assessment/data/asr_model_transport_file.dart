import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'asr_model_provisioner.dart';
import 'asr_model_release.dart';

/// Jalur transfer model untuk platform native (Android) di atas sistem berkas.
///
/// Berkas model disimpan di direktori dukungan aplikasi sehingga sherpa-onnx
/// Native FFI dapat membacanya lewat path — jalur native tidak menerima byte
/// dari asset bundle. Kebijakan cache/validasi tetap milik
/// [AsrModelProvisioner]; kelas ini hanya IO.
class AsrModelTransportFile implements AsrModelTransport {
  AsrModelTransportFile({
    required AsrModelRelease release,
    required Directory directory,
    this.baseUrl,
    Duration? idleTimeout,
    HttpClient? client,
  }) : _release = release,
       _directory = directory,
       _idleTimeout = idleTimeout ?? _defaultIdleTimeout,
       _client = client;

  static const _defaultIdleTimeout = Duration(seconds: 30);

  final Duration _idleTimeout;
  final AsrModelRelease _release;
  final Directory _directory;

  /// Sumber unduhan. `null` berarti belum dikonfigurasi: cache yang sudah ada
  /// tetap dipakai, tetapi model baru tidak dapat diunduh.
  final Uri? baseUrl;

  HttpClient? _client;

  File _file(AsrModelFile file) => File('${_directory.path}/${file.name}');

  Uri _url(AsrModelFile file) {
    final base = baseUrl;
    if (base == null) {
      throw AsrModelProvisioningException(
        AsrModelFailureKind.notConfigured,
        'Sumber model belum dikonfigurasi, sehingga ${file.name} tidak dapat '
        'diunduh.',
      );
    }
    return base.resolve('${_release.directory}/${file.name}');
  }

  @override
  Future<Uint8List?> readCached(AsrModelFile file) async {
    final entry = _file(file);
    if (!await entry.exists()) return null;
    return entry.readAsBytes();
  }

  @override
  Future<void> writeCached(AsrModelFile file, Uint8List bytes) async {
    if (!await _directory.exists()) {
      await _directory.create(recursive: true);
    }
    // Tulis lewat berkas sementara lalu ganti nama: proses yang berhenti di
    // tengah tulis tidak meninggalkan model setengah jadi dengan nama akhir.
    final target = _file(file);
    final staging = File('${target.path}.part');
    await staging.writeAsBytes(bytes, flush: true);
    await staging.rename(target.path);
  }

  @override
  Future<void> removeCached(AsrModelFile file) async {
    final entry = _file(file);
    if (await entry.exists()) await entry.delete();
    final staging = File('${entry.path}.part');
    if (await staging.exists()) await staging.delete();
  }

  @override
  Stream<Uint8List> download(AsrModelFile file) async* {
    final client = _client ??= HttpClient();
    final request = await client.openUrl('GET', _url(file));
    request.followRedirects = true;
    request.maxRedirects = 5;
    final HttpClientResponse response;
    try {
      response = await request.close().timeout(_idleTimeout);
    } on Object catch (error) {
      throw StateError('Model tidak dapat diunduh ($error).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw StateError(
        'Server menjawab ${response.statusCode} untuk ${file.name}.',
      );
    }
    // Badan respons boleh macet di tengah (jaringan seluler); tanpa batas idle
    // unduhan menggantung di fase "menyiapkan" tanpa pernah bisa dicoba lagi.
    await for (final chunk in response.timeout(_idleTimeout)) {
      yield chunk as Uint8List;
    }
  }

  void close() {
    _client?.close(force: true);
    _client = null;
  }
}
