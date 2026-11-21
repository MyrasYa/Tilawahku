import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/asr_model_provisioner.dart';
import 'package:tilawahku/features/assessment/data/asr_model_release.dart';

Uint8List _bytes(int seed, int length) => Uint8List.fromList(
  List<int>.generate(length, (index) => (index * 31 + seed) & 0xff),
);

String _hash(Uint8List bytes) => sha256.convert(bytes).toString();

const _modelName = 'model.onnx';
const _tokensName = 'tokens.txt';
final _modelBody = _bytes(7, 1200 * 1024);
final _tokensBody = _bytes(3, 128);

AsrModelRelease _release() => AsrModelRelease(
  id: 'unit',
  version: 'v1',
  directory: 'asr',
  model: AsrModelFile(
    name: _modelName,
    byteLength: _modelBody.length,
    sha256Hex: _hash(_modelBody),
  ),
  tokens: AsrModelFile(
    name: _tokensName,
    byteLength: _tokensBody.length,
    sha256Hex: _hash(_tokensBody),
  ),
);

/// Antrean respons per berkas: [Uint8List] adalah body yang dikirim,
/// selain itu dilempar sebagai kegagalan koneksi.
class _FakeTransport implements AsrModelTransport {
  _FakeTransport(Map<String, List<Object>> responses)
    : _responses = {
        for (final entry in responses.entries) entry.key: [...entry.value],
      };

  final Map<String, List<Object>> _responses;
  final Map<String, Uint8List> cache = {};

  int downloadCalls = 0;
  int removeCalls = 0;
  int writeCalls = 0;
  int chunkBytes = 400 * 1024;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<Uint8List?> readCached(AsrModelFile file) async {
    if (failRead) throw StateError('Cache Storage ditolak browser');
    return cache[file.name];
  }

  @override
  Future<void> writeCached(AsrModelFile file, Uint8List bytes) async {
    writeCalls++;
    if (failWrite) throw StateError('Kuota cache habis');
    cache[file.name] = bytes;
  }

  @override
  Future<void> removeCached(AsrModelFile file) async {
    removeCalls++;
    cache.remove(file.name);
  }

  @override
  Stream<Uint8List> download(AsrModelFile file) async* {
    downloadCalls++;
    final queue = _responses[file.name];
    if (queue == null || queue.isEmpty) {
      throw StateError('Tidak ada respons tersisa untuk ${file.name}');
    }
    final response = queue.length > 1 ? queue.removeAt(0) : queue.first;
    if (response is! Uint8List) throw response;
    for (var offset = 0; offset < response.length; offset += chunkBytes) {
      yield response.sublist(
        offset,
        math.min(offset + chunkBytes, response.length),
      );
    }
  }
}

void main() {
  test('memakai cache yang integritasnya terbukti tanpa mengunduh', () async {
    final transport = _FakeTransport({
      _modelName: [_modelBody],
    });
    transport.cache[_modelName] = _modelBody;
    transport.cache[_tokensName] = _tokensBody;
    final provisioner = AsrModelProvisioner(
      transport: transport,
      release: _release(),
    );

    final files = await provisioner.ensure();

    expect(files[_modelName], _modelBody);
    expect(files[_tokensName], _tokensBody);
    expect(transport.downloadCalls, 0);
    expect(transport.removeCalls, 0);
  });

  test('membuang cache rusak lalu mengunduh ulang', () async {
    final transport = _FakeTransport({
      _modelName: [_modelBody],
      _tokensName: [_tokensBody],
    });
    transport.cache[_modelName] = _bytes(9, _modelBody.length);
    transport.cache[_tokensName] = _tokensBody;
    final provisioner = AsrModelProvisioner(
      transport: transport,
      release: _release(),
    );

    final files = await provisioner.ensure();

    expect(files[_modelName], _modelBody);
    expect(transport.downloadCalls, 1);
    expect(transport.cache[_modelName], _modelBody);
  });

  test('cache yang terpotong dianggap rusak, bukan dipakai sebagian', () async {
    final transport = _FakeTransport({
      _modelName: [_modelBody],
      _tokensName: [_tokensBody],
    });
    transport.cache[_modelName] = _bytes(7, _modelBody.length - 1);
    final provisioner = AsrModelProvisioner(
      transport: transport,
      release: _release(),
    );

    await provisioner.ensure();

    expect(transport.downloadCalls, 2);
    expect(transport.cache[_tokensName], _tokensBody);
  });

  test(
    'unduhan dengan SHA-256 salah dihentikan dan tidak masuk cache',
    () async {
      final transport = _FakeTransport({
        _modelName: [
          _bytes(11, _modelBody.length),
          _bytes(11, _modelBody.length),
        ],
        _tokensName: [_tokensBody],
      });
      final provisioner = AsrModelProvisioner(
        transport: transport,
        release: _release(),
        maxAttempts: 2,
        sleep: (_) async {},
      );

      Object? error;
      try {
        await provisioner.ensure();
      } catch (caught) {
        error = caught;
      }

      expect(error, isA<AsrModelProvisioningException>());
      final failure = error as AsrModelProvisioningException;
      expect(failure.kind, AsrModelFailureKind.integrity);
      expect(failure.message, contains('integritas'));
      expect(transport.cache[_modelName], isNull);
      expect(transport.removeCalls, greaterThanOrEqualTo(2));
    },
  );

  test(
    'unduhan terpotong diklasifikasikan sebagai kegagalan integritas',
    () async {
      final transport = _FakeTransport({
        _modelName: [_bytes(7, _modelBody.length - 512)],
        _tokensName: [_tokensBody],
      });
      final provisioner = AsrModelProvisioner(
        transport: transport,
        release: _release(),
        maxAttempts: 1,
        sleep: (_) async {},
      );

      await expectLater(
        provisioner.ensure(),
        throwsA(
          isA<AsrModelProvisioningException>().having(
            (error) => error.kind,
            'kind',
            AsrModelFailureKind.integrity,
          ),
        ),
      );
    },
  );

  test('koneksi putus dicoba ulang dengan jeda meningkat', () async {
    final transport = _FakeTransport({
      _modelName: [const _ConnectionLost(), _modelBody],
      _tokensName: [_tokensBody],
    });
    final delays = <Duration>[];
    final provisioner = AsrModelProvisioner(
      transport: transport,
      release: _release(),
      sleep: (delay) async => delays.add(delay),
    );

    final files = await provisioner.ensure();

    expect(files[_modelName], _modelBody);
    // Model: satu percobaan putus + satu berhasil, lalu tokens.
    expect(transport.downloadCalls, 3);
    expect(delays, [const Duration(milliseconds: 500)]);
  });

  test('semua percobaan gagal mengembalikan kegagalan jaringan', () async {
    final transport = _FakeTransport({
      _modelName: [
        const _ConnectionLost(),
        const _ConnectionLost(),
        const _ConnectionLost(),
      ],
    });
    final provisioner = AsrModelProvisioner(
      transport: transport,
      release: _release(),
      sleep: (_) async {},
    );

    Object? error;
    try {
      await provisioner.ensure();
    } catch (caught) {
      error = caught;
    }

    final failure = error as AsrModelProvisioningException;
    expect(failure.kind, AsrModelFailureKind.network);
    expect(failure.message, contains('3 percobaan'));
    expect(transport.downloadCalls, 3);
  });

  test('gagal membaca cache diperlakukan sebagai cache kosong', () async {
    final transport = _FakeTransport({
      _modelName: [_modelBody],
      _tokensName: [_tokensBody],
    });
    transport.failRead = true;
    final provisioner = AsrModelProvisioner(
      transport: transport,
      release: _release(),
    );

    final files = await provisioner.ensure();

    expect(files[_tokensName], _tokensBody);
    expect(transport.downloadCalls, 2);
  });

  test('gagal menulis cache tidak membatalkan penilaian', () async {
    final transport = _FakeTransport({
      _modelName: [_modelBody],
      _tokensName: [_tokensBody],
    });
    transport.failWrite = true;
    final provisioner = AsrModelProvisioner(
      transport: transport,
      release: _release(),
    );

    final files = await provisioner.ensure();

    expect(files[_modelName], _modelBody);
    expect(transport.writeCalls, 2);
  });

  test(
    'progres dinaikkan per berkas dan dibatasi agar UI tidak banjir',
    () async {
      final transport = _FakeTransport({
        _modelName: [_modelBody],
        _tokensName: [_tokensBody],
      });
      final fractions = <double>[];
      final messages = <String>[];
      final provisioner = AsrModelProvisioner(
        transport: transport,
        release: _release(),
      );

      await provisioner.ensure(
        onProgress: (fraction, message) {
          fractions.add(fraction);
          messages.add(message);
        },
      );

      // 1,2 MB model + 128 B token dengan laporan tiap 512 KB.
      expect(fractions.length, lessThan(12));
      for (var index = 1; index < fractions.length; index++) {
        expect(fractions[index], greaterThanOrEqualTo(fractions[index - 1]));
      }
      expect(fractions.last, 1.0);
      expect(messages.first, 'Memeriksa cache model');
      expect(messages.last, 'Model siap');
      expect(
        messages.any((message) => message.startsWith('Mengunduh model · ')),
        isTrue,
      );
      expect(
        messages.where((message) => message.startsWith('Mengunduh model · ')),
        hasLength(1),
      );
    },
  );
}

class _ConnectionLost implements Exception {
  const _ConnectionLost();

  @override
  String toString() => 'Connection reset by peer';
}
