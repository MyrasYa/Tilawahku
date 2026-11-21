import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/asr_model_release.dart';

import '../tool/stage_web_asr_model.dart';

/// Tool staging adalah satu-satunya jalan bobot model masuk ke hasil build
/// setelah ia diabaikan Git. Yang dijamin karena itu bukan "berkas tersalin"
/// melainkan "berkas yang tersalin cocok dengan rilis".
const _fixture = AsrModelFile(
  name: 'model.int8.onnx',
  byteLength: 4,
  sha256Hex: _shaAbcd,
);

const _shaAbcd =
    '88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589';
final _abcd = Uint8List.fromList([0x61, 0x62, 0x63, 0x64]);

void main() {
  late File target;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('tilawahku-asr-staging');
    target = File('${root.path}/asr/${_fixture.name}');
  });
  tearDown(() => root.deleteSync(recursive: true));

  group('stageFile', () {
    test('menulis hanya setelah ukuran dan SHA-256 cocok', () async {
      final outcome = await stageFile(
        file: _fixture,
        target: target,
        source: () async => _abcd,
      );

      expect(outcome, StageOutcome.written);
      expect(target.readAsBytesSync(), _abcd);
      // Berkas sementara bukan model yang sah dan tidak boleh tertinggal.
      expect(File('${target.path}.part').existsSync(), isFalse);
    });

    test('menolak SHA-256 yang berbeda tanpa meninggalkan berkas', () async {
      // Ukuran benar, isi berbeda: persis kegagalan yang tidak boleh lolos
      // ke deployment karena hasil build-nya tetap terbaca sebagai model.
      final rusak = Uint8List.fromList('wxyz'.codeUnits);
      expect(rusak.length, _fixture.byteLength);

      await expectLater(
        stageFile(file: _fixture, target: target, source: () async => rusak),
        throwsA(isA<StageFailure>()),
      );
      expect(target.existsSync(), isFalse);
      expect(File('${target.path}.part').existsSync(), isFalse);
    });

    test('menolak ukuran yang tidak cocok', () async {
      await expectLater(
        stageFile(
          file: _fixture,
          target: target,
          source: () async => Uint8List.fromList([0x61, 0x62]),
        ),
        throwsA(
          isA<StageFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('2 B'), contains('4 B')),
          ),
        ),
      );
      expect(target.existsSync(), isFalse);
    });

    test(
      'melewati target yang sudah terverifikasi tanpa membaca sumber',
      () async {
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(_abcd);
        var dibaca = 0;

        final outcome = await stageFile(
          file: _fixture,
          target: target,
          source: () async {
            dibaca++;
            return null;
          },
        );

        expect(outcome, StageOutcome.alreadyValid);
        expect(dibaca, 0, reason: 'target sah tidak boleh diunduh ulang');
        expect(target.readAsBytesSync(), _abcd);
      },
    );

    test('kegagalan staging tidak menimpa target yang sudah ada', () async {
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(Uint8List.fromList([9, 9, 9, 9]));

      await expectLater(
        stageFile(
          file: _fixture,
          target: target,
          source: () async => Uint8List.fromList('wxyz'.codeUnits),
        ),
        throwsA(isA<StageFailure>()),
      );
      // Build yang sedang berjalan tidak boleh rusak karena staging gagal.
      expect(target.readAsBytesSync(), Uint8List.fromList([9, 9, 9, 9]));
    });

    test('mengganti target lama yang isinya tidak sah', () async {
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(Uint8List.fromList([9, 9, 9, 9]));

      final outcome = await stageFile(
        file: _fixture,
        target: target,
        source: () async => _abcd,
      );

      expect(outcome, StageOutcome.written);
      expect(target.readAsBytesSync(), _abcd);
    });

    test(
      'sumber yang kosong menyebut konfigurasi URL, bukan hasil palsu',
      () async {
        await expectLater(
          stageFile(file: _fixture, target: target, source: () async => null),
          throwsA(
            isA<StageFailure>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('ASR_MODEL_BASE_URL'),
                contains('belum dibakukan'),
              ),
            ),
          ),
        );
        expect(target.existsSync(), isFalse);
      },
    );
  });

  group('kontrak staging dengan runtime Web', () {
    test('nama berkas yang distage sama dengan yang di-fetch runtime', () {
      // `AsrModelTransportWeb` mengambil `<directory>/<name>`; kalau tool
      // menstage nama lain, build-nya lolos verifikasi tapi 404 saat dipakai.
      expect(
        asrWebModelRelease.files.map((f) => f.name),
        containsAll(<String>['model.int8.onnx', 'tokens.txt']),
      );
      expect(_fixture.name, asrWebModelRelease.model.name);
    });

    test('prosedur staging terdokumentasi di samping berkas rilis', () {
      expect(
        File('web/${asrWebModelRelease.directory}/README.md').existsSync(),
        isTrue,
      );
    });
  });
}
