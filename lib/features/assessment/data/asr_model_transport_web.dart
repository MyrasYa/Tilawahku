import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'asr_model_provisioner.dart';
import 'asr_model_release.dart';

/// Transport model ASR untuk Web: `fetch` same-origin untuk unduhan bertahap
/// dan Cache Storage bernama versi rilis agar model tidak diunduh dua kali.
///
/// File model diletakkan di `web/<release.directory>/` sehingga ikut tersalin
/// ke akar hasil build tanpa masuk ke `flutter_assets`.
class AsrModelTransportWeb implements AsrModelTransport {
  AsrModelTransportWeb(this._release);

  final AsrModelRelease _release;

  String _url(AsrModelFile file) =>
      Uri.base.resolve('${_release.directory}/${file.name}').toString();

  /// Cache Storage hanya tersedia pada secure context; bila browser menolaknya
  /// model tetap dipakai dari unduhan, hanya saja tidak diunduh sekali saja.
  Future<web.Cache?> _openCache() async {
    try {
      return await web.window.caches.open(_release.cacheName).toDart;
    } on Object {
      return null;
    }
  }

  @override
  Future<Uint8List?> readCached(AsrModelFile file) async {
    final cache = await _openCache();
    if (cache == null) return null;
    final response = await cache.match(_url(file).toJS).toDart;
    if (response == null) return null;
    final buffer = (await response.arrayBuffer().toDart).toDart;
    return buffer.asUint8List();
  }

  @override
  Future<void> writeCached(AsrModelFile file, Uint8List bytes) async {
    final cache = await _openCache();
    if (cache == null) return;
    await cache.put(_url(file).toJS, web.Response(bytes.toJS)).toDart;
  }

  @override
  Future<void> removeCached(AsrModelFile file) async {
    final cache = await _openCache();
    if (cache == null) return;
    await cache.delete(_url(file).toJS).toDart;
  }

  @override
  Stream<Uint8List> download(AsrModelFile file) async* {
    final response = await web.window.fetch(_url(file).toJS).toDart;
    if (!response.ok) {
      throw StateError(
        'Model ${file.name} tidak tersedia di server (HTTP ${response.status}).',
      );
    }
    final body = response.body;
    if (body == null) {
      throw StateError('Respons tanpa body untuk model ${file.name}.');
    }
    final reader = body.getReader() as web.ReadableStreamDefaultReader;
    while (true) {
      final result = await reader.read().toDart;
      if (result.done) return;
      final chunk = result.value;
      if (chunk != null) yield (chunk as JSUint8Array).toDart;
    }
  }
}
