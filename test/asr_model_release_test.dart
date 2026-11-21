import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/asr_model_release.dart';

/// Verifikasi rilis model yang benar-benar disajikan build Web: berkas harus
/// ada di `web/asr/`, cocok dengan SHA-256 dan ukuran yang dikunci kode, dan
/// tidak boleh ikut masuk bundel `flutter_assets` maupun bundel Git.
void main() {
  group('rilis model web/asr', () {
    for (final file in asrWebModelRelease.files) {
      final path = 'web/${asrWebModelRelease.directory}/${file.name}';
      // Bobot ONNX diabaikan Git sehingga checkout bersih tidak punya apa pun
      // untuk dicocokkan; staging-lah yang mengunduh dan memverifikasinya.
      final absen = !File(path).existsSync();
      test('$path cocok dengan SHA-256 rilis', () async {
        final bytes = await File(path).readAsBytes();
        expect(bytes.lengthInBytes, file.byteLength);
        expect(sha256.convert(bytes).toString(), file.sha256Hex);
      }, skip: absen ? '$path belum distage (lihat web/asr/README.md)' : false);
    }

    test('model tidak dideklarasikan sebagai asset Flutter', () {
      final lines = File('pubspec.yaml').readAsStringSync().split('\n');
      final declared = <String>[];
      final assetLines = lines
          .skipWhile((line) => line.trim() != 'assets:')
          .skip(1);
      for (final line in assetLines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('- ')) break;
        declared.add(trimmed.substring(2));
      }
      expect(declared, isNotEmpty);
      expect(
        declared.where(
          (asset) =>
              asset.contains('/asr/') || asset.contains('model.int8.onnx'),
        ),
        isEmpty,
        reason: 'Model 36 MB tidak boleh masuk flutter_assets',
      );
    });

    test('lisensi model ikut disajikan di sisi web', () {
      expect(
        File('web/${asrWebModelRelease.directory}/LICENSE').existsSync(),
        isTrue,
      );
    });

    test('cache storage dipisahkan per versi rilis', () {
      expect(
        asrWebModelRelease.cacheName,
        contains(asrWebModelRelease.version),
      );
      expect(
        asrWebModelRelease.totalBytes,
        asrWebModelRelease.files.fold(
          0,
          (int sum, file) => sum + file.byteLength,
        ),
      );
    });

    test('hanya bobot model yang diabaikan Git, bukan isi web/asr', () {
      final di = 'web/${asrWebModelRelease.directory}';
      expect(
        _ignoredByGit('$di/model.int8.onnx'),
        isTrue,
        reason: '36 MB bobot tidak boleh masuk bundel Git',
      );
      // Sisa penulisan tool staging juga tidak boleh ikut terlacak.
      expect(_ignoredByGit('$di/model.int8.onnx.part'), isTrue);

      for (final pendukung in ['tokens.txt', 'LICENSE', 'README.md']) {
        expect(
          _ignoredByGit('$di/$pendukung'),
          isFalse,
          reason: '$pendukung diperlukan untuk membaca rilis dan layak Git',
        );
      }
      expect(
        _ignoredByGit(di),
        isFalse,
        reason:
            'aturan harus spesifik ke berkas bobot, tidak menutupi '
            'seluruh direktori',
      );
    }, skip: _gitTersedia ? false : 'binari git tidak tersedia');
  });
}

/// Tafsir Git yang sebenarnya atas `.gitignore`, bukan perkiraan pola sendiri.
final _gitTersedia = _git(['rev-parse', '--is-inside-work-tree']) == 0;

int? _git(List<String> args) {
  try {
    return Process.runSync('git', args).exitCode;
  } on ProcessException {
    return null;
  }
}

bool _ignoredByGit(String path) =>
    _git(['check-ignore', '-q', '--no-index', '--', path]) == 0;
