import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/asr_model_provisioner.dart';
import 'package:tilawahku/features/assessment/data/asr_model_release.dart';
import 'package:tilawahku/features/assessment/data/asr_model_transport_file.dart';

Uint8List _bytes(int seed, int length) {
  final bytes = Uint8List(length);
  var value = seed;
  for (var i = 0; i < length; i++) {
    value = (value * 1103515245 + 12345) & 0x7fffffff;
    bytes[i] = value & 0xff;
  }
  return bytes;
}

const _modelName = 'model.onnx';
const _tokensName = 'tokens.txt';
final _modelBody = _bytes(7, 1_200_000);
final _tokensBody = _bytes(3, 128);

AsrModelRelease _release() => AsrModelRelease(
  id: 'test-release',
  version: 'v1',
  directory: 'asr',
  model: AsrModelFile(
    name: _modelName,
    byteLength: _modelBody.length,
    sha256Hex: sha256.convert(_modelBody).toString(),
  ),
  tokens: AsrModelFile(
    name: _tokensName,
    byteLength: _tokensBody.length,
    sha256Hex: sha256.convert(_tokensBody).toString(),
  ),
);

/// Server localhost sungguhan: jalur unduh native memakai `HttpClient`, jadi
/// uji memakai HTTP nyata, bukan stub.
Future<(HttpServer, Uri)> _serve(Map<String, Uint8List> bodies) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    final name = request.uri.pathSegments.last;
    final body = bodies[name];
    if (body == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
      return;
    }
    request.response.add(body);
    request.response.close();
  });
  return (server, Uri.parse('http://127.0.0.1:${server.port}/asr/'));
}

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('tilawahku-asr-file');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test(
    'unduh pertama menulis berkas dan cache terpakai tanpa jaringan',
    () async {
      var hits = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        hits++;
        final body = switch (request.uri.pathSegments.last) {
          _modelName => _modelBody,
          _tokensName => _tokensBody,
          _ => null,
        };
        if (body == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.add(body);
        }
        request.response.close();
      });
      final transport = AsrModelTransportFile(
        release: _release(),
        directory: directory,
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}/asr/'),
      );
      final release = _release();
      final provisioner = AsrModelProvisioner(
        transport: transport,
        release: release,
      );

      final downloaded = await provisioner.ensure();
      expect(
        File('${directory.path}/$_modelName').readAsBytesSync(),
        downloaded[_modelName],
      );
      expect(hits, 2);

      // Unduhan kedua tidak boleh menyentuh jaringan: berkas di cache diverifikasi
      // ulang sebelum dipakai.
      final cached = await provisioner.ensure();
      expect(hits, 2);
      expect(cached[_modelName], downloaded[_modelName]);
      transport.close();
      await server.close(force: true);
    },
  );

  test('berkas cache terpotong terdeteksi lalu diunduh ulang', () async {
    final (server, url) = await _serve({
      _modelName: _modelBody,
      _tokensName: _tokensBody,
    });
    File('${directory.path}/$_modelName')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_modelBody.sublist(0, _modelBody.length - 997));
    File('${directory.path}/$_tokensName')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_tokensBody);
    final transport = AsrModelTransportFile(
      release: _release(),
      directory: directory,
      baseUrl: url,
    );

    final files = await AsrModelProvisioner(
      transport: transport,
      release: _release(),
    ).ensure();

    expect(files[_modelName], _modelBody);
    expect(
      File('${directory.path}/$_modelName').lengthSync(),
      _modelBody.length,
    );
    expect(
      File('${directory.path}/$_modelName.part').existsSync(),
      isFalse,
      reason: 'berkas sementara harus hilang setelah rename',
    );
    transport.close();
    await server.close(force: true);
  });

  test(
    'SHA-256 tidak cocok tidak pernah ditinggalkan di penyimpanan',
    () async {
      final (server, url) = await _serve({
        _modelName: _bytes(11, _modelBody.length),
        _tokensName: _tokensBody,
      });
      final transport = AsrModelTransportFile(
        release: _release(),
        directory: directory,
        baseUrl: url,
      );

      await expectLater(
        AsrModelProvisioner(transport: transport, release: _release()).ensure(),
        throwsA(
          isA<AsrModelProvisioningException>().having(
            (error) => error.kind,
            'kind',
            AsrModelFailureKind.integrity,
          ),
        ),
      );
      expect(File('${directory.path}/$_modelName').existsSync(), isFalse);
      transport.close();
      await server.close(force: true);
    },
  );

  test(
    'baseUrl belum dikonfigurasi: cache valid tetap dipakai, unduhan ditolak',
    () async {
      final release = _release();
      File('${directory.path}/$_modelName')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_modelBody);
      File('${directory.path}/$_tokensName')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_tokensBody);

      final usable = AsrModelTransportFile(
        release: release,
        directory: directory,
      );
      final files = await AsrModelProvisioner(
        transport: usable,
        release: release,
      ).ensure();
      expect(
        files[_modelName],
        _modelBody,
        reason: 'offline setelah cache ada',
      );

      final empty = Directory.systemTemp.createTempSync('tilawahku-asr-empty');
      final blocked = AsrModelTransportFile(release: release, directory: empty);
      await expectLater(
        AsrModelProvisioner(transport: blocked, release: release).ensure(),
        throwsA(
          isA<AsrModelProvisioningException>().having(
            (error) => error.kind,
            'kind',
            AsrModelFailureKind.notConfigured,
          ),
        ),
      );
      blocked.close();
      usable.close();
      empty.deleteSync(recursive: true);
    },
  );

  test('server menjawab 404 dilaporkan sebagai kegagalan jaringan', () async {
    final (server, url) = await _serve({});
    final transport = AsrModelTransportFile(
      release: _release(),
      directory: directory,
      baseUrl: url,
    );

    await expectLater(
      AsrModelProvisioner(
        transport: transport,
        release: _release(),
        maxAttempts: 1,
        sleep: (_) async {},
      ).ensure(),
      throwsA(
        isA<AsrModelProvisioningException>().having(
          (error) => error.message,
          'message',
          contains('404'),
        ),
      ),
    );
    transport.close();
    await server.close(force: true);
  });

  test('readCached menghasilkan byte persis seperti ditulis', () async {
    final transport = AsrModelTransportFile(
      release: _release(),
      directory: directory,
    );
    final file = _release().model;
    await transport.writeCached(file, _modelBody);
    expect(await transport.readCached(file), _modelBody);
    await transport.removeCached(file);
    expect(await transport.readCached(file), isNull);
    transport.close();
  });

  test('unduhan terpotong memicu unduh ulang sampai berkas utuh', () async {
    // Server mengirim body lebih pendek pada percobaan pertama; panjang yang
    // tidak cocok rilis terdeteksi sebagai kegagalan integritas lalu diulang.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var modelAttempts = 0;
    server.listen((request) {
      final name = request.uri.pathSegments.last;
      if (name == _tokensName) {
        request.response.add(_tokensBody);
        request.response.close();
        return;
      }
      modelAttempts++;
      request.response.add(
        modelAttempts == 1 ? _modelBody.sublist(0, 300_000) : _modelBody,
      );
      request.response.close();
    });
    final transport = AsrModelTransportFile(
      release: _release(),
      directory: directory,
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}/asr/'),
    );

    final files = await AsrModelProvisioner(
      transport: transport,
      release: _release(),
    ).ensure();
    expect(modelAttempts, 2);
    expect(files[_modelName], _modelBody);
    expect(
      sha256.convert(files[_modelName]!).toString(),
      _release().model.sha256Hex,
    );
    expect(files[_tokensName], _tokensBody);
    transport.close();
    await server.close(force: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'unduhan yang macet di tengah badan respons tidak menggantung',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response.add(_modelBody.sublist(0, 4096));
        // Sengaja tidak ditutup: tanpa batas idle, fase "menyiapkan" tergantung
        // selamanya dan kebijakan retry tidak pernah berjalan.
      });
      final transport = AsrModelTransportFile(
        release: _release(),
        directory: directory,
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}/asr/'),
        idleTimeout: const Duration(milliseconds: 200),
      );

      await expectLater(
        transport.download(_release().model).toList(),
        throwsA(isA<TimeoutException>()),
      );
      transport.close();
      await server.close(force: true);
    },
  );
}
