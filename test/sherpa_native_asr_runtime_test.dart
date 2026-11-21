import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/asr_model_provisioner.dart';
import 'package:tilawahku/features/assessment/data/asr_model_release.dart';
import 'package:tilawahku/features/assessment/data/sherpa_native_asr_runtime.dart';
import 'package:tilawahku/features/assessment/domain/arabic_comparison.dart';
import 'package:tilawahku/features/assessment/domain/recitation_audio.dart';

Uint8List _bytes(int seed, int length) {
  final bytes = Uint8List(length);
  var value = seed;
  for (var i = 0; i < length; i++) {
    value = (value * 1103515245 + 12345) & 0x7fffffff;
    bytes[i] = value & 0xff;
  }
  return bytes;
}

final _modelBody = _bytes(7, 4096);
final _tokensBody = _bytes(3, 128);

final _release = AsrModelRelease(
  id: 'test-release',
  version: 'v1',
  directory: 'asr',
  model: AsrModelFile(
    name: 'model.onnx',
    byteLength: _modelBody.length,
    sha256Hex: sha256.convert(_modelBody).toString(),
  ),
  tokens: AsrModelFile(
    name: 'tokens.txt',
    byteLength: _tokensBody.length,
    sha256Hex: sha256.convert(_tokensBody).toString(),
  ),
);

class _FakeRecognizer implements NativeAsrRecognizer {
  _FakeRecognizer(this.transcript);

  final String transcript;
  final recognized = <RecitationAudio>[];
  int disposeCalls = 0;

  @override
  String recognize(RecitationAudio audio) {
    recognized.add(audio);
    return transcript;
  }

  @override
  void dispose() => disposeCalls++;
}

const _basmalahSpoken = 'بسم الله الرحمن الرحيم';

void main() {
  late Directory directory;
  late Directory modelDirectory;
  AsrModelPaths? lastPaths;
  int? lastThreads;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('tilawahku-asr-native');
    modelDirectory = Directory('${directory.path}/asr')..createSync();
    File('${modelDirectory.path}/model.onnx').writeAsBytesSync(_modelBody);
    File('${modelDirectory.path}/tokens.txt').writeAsBytesSync(_tokensBody);
    lastPaths = null;
    lastThreads = null;
  });

  tearDown(() => directory.deleteSync(recursive: true));

  SherpaNativeAsrRuntime build(NativeAsrRecognizer recognizer) {
    return SherpaNativeAsrRuntime(
      release: _release,
      directory: modelDirectory,
      recognizerFactory: (paths, threads) async {
        lastPaths = paths;
        lastThreads = threads;
        return recognizer;
      },
    );
  }

  test(
    'prepare memuat recognizer dari berkas model yang terverifikasi',
    () async {
      final runtime = build(_FakeRecognizer(_basmalahSpoken));

      await runtime.prepare();

      expect(lastPaths?.modelPath, '${modelDirectory.path}/model.onnx');
      expect(lastPaths?.tokensPath, '${modelDirectory.path}/tokens.txt');
      expect(lastThreads, greaterThanOrEqualTo(1));
      expect(lastThreads, lessThanOrEqualTo(2));
      runtime.dispose();
    },
  );

  test('prepare berulang hanya memuat satu recognizer', () async {
    var creates = 0;
    final recognizer = _FakeRecognizer(_basmalahSpoken);
    final runtime = SherpaNativeAsrRuntime(
      release: _release,
      directory: modelDirectory,
      recognizerFactory: (_, _) async {
        creates++;
        return recognizer;
      },
    );

    await Future.wait([runtime.prepare(), runtime.prepare()]);
    await runtime.prepare();

    expect(creates, 1);
    expect(recognizer.disposeCalls, 0);
    runtime.dispose();
  });

  test('recognize sebelum prepare menolak, tanpa hasil dummy', () async {
    final runtime = build(_FakeRecognizer(_basmalahSpoken));

    await expectLater(
      runtime.recognize(RecitationAudio(Float32List(16000))),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('belum siap'),
        ),
      ),
    );
    runtime.dispose();
  });

  test('audio kosong ditolak sebelum masuk engine', () async {
    final recognizer = _FakeRecognizer(_basmalahSpoken);
    final runtime = build(recognizer);
    await runtime.prepare();

    await expectLater(
      runtime.recognize(RecitationAudio(Float32List(0))),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('tidak berisi audio'),
        ),
      ),
    );
    expect(recognizer.recognized, isEmpty);
    runtime.dispose();
  });

  test('audio 16 kHz diteruskan apa adanya ke recognizer', () async {
    final recognizer = _FakeRecognizer(_basmalahSpoken);
    final runtime = build(recognizer);
    await runtime.prepare();

    final samples = Float32List(32000)..[0] = 0.25;
    final transcript = await runtime.recognize(RecitationAudio(samples));

    expect(transcript, _basmalahSpoken);
    expect(recognizer.recognized.single.sampleRate, asrSampleRate);
    expect(recognizer.recognized.single.samples, samples);
    expect(recognizer.recognized.single.durationSeconds, 2);
    runtime.dispose();
  });

  test('kegagalan memuat pustaka native dilaporkan apa adanya', () async {
    var attempts = 0;
    final runtime = SherpaNativeAsrRuntime(
      release: _release,
      directory: modelDirectory,
      recognizerFactory: (_, _) async {
        attempts++;
        throw StateError(
          "Failed to load dynamic library 'libsherpa-onnx-c-api.so'",
        );
      },
    );

    await expectLater(
      runtime.prepare(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('libsherpa-onnx-c-api'),
        ),
      ),
    );
    expect(attempts, 1);

    // Persiapan yang gagal tidak mengunci runtime: percobaan berikutnya boleh
    // memuat ulang.
    await expectLater(runtime.prepare(), throwsA(isA<StateError>()));
    expect(attempts, 2);
    runtime.dispose();
  });

  test('halaman ditutup saat model dimuat membuang recognizer', () async {
    final recognizer = _FakeRecognizer(_basmalahSpoken);
    final gate = Completer<void>();
    final runtime = SherpaNativeAsrRuntime(
      release: _release,
      directory: modelDirectory,
      recognizerFactory: (_, _) async {
        await gate.future;
        return recognizer;
      },
    );

    final preparing = runtime.prepare();
    await Future<void>.delayed(Duration.zero);
    runtime.dispose();
    gate.complete();
    await preparing;

    expect(recognizer.disposeCalls, 1);
    await expectLater(
      runtime.recognize(RecitationAudio(Float32List(160))),
      throwsA(isA<StateError>()),
    );
  });

  test('model belum terunduh dan sumber belum dikonfigurasi', () async {
    final runtime = SherpaNativeAsrRuntime(
      release: _release,
      directory: Directory('${directory.path}/kosong'),
      recognizerFactory: (_, _) async => _FakeRecognizer(_basmalahSpoken),
    );

    await expectLater(
      runtime.prepare(),
      throwsA(
        isA<AsrModelProvisioningException>().having(
          (error) => error.kind,
          'kind',
          AsrModelFailureKind.notConfigured,
        ),
      ),
    );
    runtime.dispose();
  });

  test('berkas model setengah jadi ditolak sebelum engine dimuat', () async {
    File(
      '${modelDirectory.path}/model.onnx',
    ).writeAsBytesSync(_modelBody.sublist(0, _modelBody.length - 8));
    var creates = 0;
    final runtime = SherpaNativeAsrRuntime(
      release: _release,
      directory: modelDirectory,
      baseUrl: Uri.parse('http://127.0.0.1:1/asr/'),
      recognizerFactory: (_, _) async {
        creates++;
        return _FakeRecognizer(_basmalahSpoken);
      },
    );

    await expectLater(
      runtime.prepare(),
      throwsA(isA<AsrModelProvisioningException>()),
    );
    expect(creates, 0);
    runtime.dispose();
  });

  test('transkrip native diteruskan ke Assessment Engine B1', () async {
    final runtime = build(_FakeRecognizer(_basmalahSpoken));
    await runtime.prepare();

    final transcript = await runtime.recognize(
      RecitationAudio(Float32List(16000)),
    );
    final comparison = compareArabicWords(
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      transcript,
    );

    expect(comparison.assessable, isTrue);
    expect(comparison.referenceWordCount, 4);
    expect(comparison.wordEdits, 0);
    expect(comparison.matchPercent, 100);
    runtime.dispose();
  });
}
