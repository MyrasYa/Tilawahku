// Stage berkas rilis model ASR Web ke hasil build, dengan verifikasi ukuran
// dan SHA-256 sebelum dipakai.
//
// Bobot ONNX 36 MB sengaja tidak masuk Git (lihat `.gitignore`) dan tidak masuk
// `flutter_assets`. Build yang siap disajikan karena itu dibentuk dalam dua
// langkah:
//
//   flutter build web --release
//   dart run tool/stage_web_asr_model.dart --out build/web
//
// Struktur yang dihasilkan harus sama dengan yang diminta runtime Web, yaitu
// `<out>/<release.directory>/<file.name>`, karena `AsrModelTransportWeb`
// mengambil `asr/<name>` relatif terhadap `Uri.base`.
//
// Sumber berkas, berurutan: direktori `--source` (bawaan `web/asr`), lalu
// unduhan dari `--base-url` / environment `ASR_MODEL_BASE_URL` kalau sumber
// lokal tidak lengkap. URL hosting TIDAK punya bawaan — ia harus ditentukan
// pemilik repo, dan tanpa itu tool berhenti dengan pesan yang menjelaskan.
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:tilawahku/features/assessment/data/asr_model_release.dart';

enum StageOutcome { alreadyValid, written }

class StageFailure implements Exception {
  StageFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

const _licenseFileName = 'LICENSE';

const _usage = '''
Pemakaian: dart run tool/stage_web_asr_model.dart [ pilihan ]

  --out <dir>       direktori hasil build yang diisi <dir>/asr/ (boleh lebih
                    dari satu, mis. --out build/web --out build/web_probe)
  --source <dir>    direktori cache berkas model lokal (bawaan: web/asr)
  --base-url <url>  sumber unduhan bila cache lokal tidak lengkap; bisa juga
                    lewat environment ASR_MODEL_BASE_URL
  --help            tampilkan pesan ini
''';

Future<void> main(List<String> args) async {
  try {
    final options = _Options.parse(args);
    if (options.help) {
      stdout.writeln(_usage);
      return;
    }
    final failures = await _run(options);
    if (failures > 0) exitCode = 1;
  } on StageFailure catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

/// Stage seluruh berkas rilis ke setiap target. Mengembalikan jumlah berkas
/// yang gagal (0 = seluruhnya terverifikasi).
Future<int> _run(_Options options) async {
  final release = asrWebModelRelease;
  var failures = 0;
  for (final out in options.targets) {
    final directory = Directory(out);
    if (!directory.existsSync()) {
      stderr.writeln(
        'Target build tidak ada: $out (jalankan '
        '"flutter build web --release" terlebih dahulu).',
      );
      failures += release.files.length + 1;
      continue;
    }
    stdout.writeln('== $out (rilis ${release.version}) ==');
    for (final file in release.files) {
      try {
        final outcome = await stageFile(
          file: file,
          target: File('${directory.path}/${release.directory}/${file.name}'),
          source: options.candidateBytes(file),
        );
        stdout.writeln('  ${file.name}: ${_label(outcome)}');
      } on StageFailure catch (error) {
        // Pesan StageFailure sudah menyebut nama berkasnya.
        stderr.writeln('  ${error.message}');
        failures++;
      }
    }
    failures += await _stageLicense(options, directory);
  }
  if (failures > 0) {
    stderr.writeln('\nStage model gagal pada $failures berkas.');
  }
  return failures;
}

String _label(StageOutcome outcome) => switch (outcome) {
  StageOutcome.alreadyValid => 'sudah terverifikasi, dilewati',
  StageOutcome.written => 'ditulis setelah verifikasi',
};

/// Lisensi model ikut disajikan di samping bobotnya; berkas ini kecil dan
/// memang dilacak Git, jadi cukup disalin tanpa verifikasi hash.
Future<int> _stageLicense(_Options options, Directory out) async {
  final target = File(
    '${out.path}/${asrWebModelRelease.directory}/$_licenseFileName',
  );
  if (await target.exists()) {
    stdout.writeln('  $_licenseFileName: sudah ada');
    return 0;
  }
  final source = File('${options.source}/$_licenseFileName');
  if (!await source.exists()) {
    stderr.writeln(
      '  $_licenseFileName: tidak ada di ${options.source} maupun '
      'di ${target.path}.',
    );
    return 1;
  }
  await target.parent.create(recursive: true);
  await source.copy(target.path);
  stdout.writeln('  $_licenseFileName: disalin dari ${options.source}');
  return 0;
}

class _Options {
  _Options._({
    required this.targets,
    required this.source,
    required this.baseUrl,
    required this.help,
  });

  final List<String> targets;
  final String source;
  final Uri? baseUrl;
  final bool help;

  static _Options parse(List<String> args) {
    final targets = <String>[];
    String? source;
    String? baseUrl;
    var help = false;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--help':
        case '-h':
          help = true;
        case '--out':
          targets.add(_value(args, ++i, arg));
        case '--source':
          source = _value(args, ++i, arg);
        case '--base-url':
          baseUrl = _value(args, ++i, arg);
        default:
          throw StageFailure('Pilihan tidak dikenal: $arg\n\n$_usage');
      }
    }
    final configured = baseUrl ?? Platform.environment['ASR_MODEL_BASE_URL'];
    return _Options._(
      targets: targets.isEmpty ? const ['build/web'] : targets,
      source: source ?? 'web/${asrWebModelRelease.directory}',
      baseUrl: configured == null || configured.isEmpty
          ? null
          : Uri.parse(configured.endsWith('/') ? configured : '$configured/'),
      help: help,
    );
  }

  static String _value(List<String> args, int index, String flag) {
    if (index >= args.length) {
      throw StageFailure('$flag membutuhkan nilai.');
    }
    return args[index];
  }

  /// Baca kandidat dari cache lokal, lalu dari unduhan bila tidak ada.
  Future<Uint8List?> Function() candidateBytes(AsrModelFile file) {
    return () async {
      final local = File('$source/${file.name}');
      if (await local.exists()) return local.readAsBytes();
      final base = baseUrl;
      if (base == null) return null;
      return _download(base.resolve(file.name), file);
    };
  }
}

Future<Uint8List> _download(Uri url, AsrModelFile file) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw StageFailure(
        'Unduhan ${response.statusCode} untuk ${file.name} dari $url.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > file.byteLength) {
        throw StageFailure(
          '${file.name} melebihi ukuran rilis (${file.byteLength} B).',
        );
      }
    }
    return builder.takeBytes();
  } on StageFailure {
    rethrow;
  } catch (error) {
    throw StageFailure('Gagal mengunduh $url: $error');
  } finally {
    client.close(force: true);
  }
}

/// Tulis [file] ke [target] hanya bila ukuran dan SHA-256-nya cocok dengan
/// rilis. Berkas target yang sudah valid tidak disentuh ulang.
Future<StageOutcome> stageFile({
  required AsrModelFile file,
  required File target,
  required Future<Uint8List?> Function() source,
}) async {
  if (await target.exists() && await _matches(target, file)) {
    return StageOutcome.alreadyValid;
  }
  final bytes = await source();
  if (bytes == null) {
    throw StageFailure(
      '${file.name} tidak tersedia. Letakkan di direktori sumber atau tentukan '
      'ASR_MODEL_BASE_URL / --base-url (URL hosting belum dibakukan di repo '
      'ini).',
    );
  }
  if (bytes.length != file.byteLength ||
      sha256.convert(bytes).toString() != file.sha256Hex) {
    throw StageFailure(
      '${file.name} gagal verifikasi: ${bytes.length} B dengan SHA-256 yang '
      'tidak cocok dengan rilis (diharapkan ${file.byteLength} B, '
      '${file.sha256Hex.substring(0, 12)}…). Berkas tidak ditulis.',
    );
  }
  await target.parent.create(recursive: true);
  // Tulis lewat berkas sementara agar hasil yang setengah jalan tidak pernah
  // tampak sebagai model yang sah.
  final part = File('${target.path}.part');
  await part.writeAsBytes(bytes, flush: true);
  if (!await _matches(part, file)) {
    await part.delete();
    throw StageFailure(
      '${file.name} tidak cocok setelah ditulis ke ${target.path}.',
    );
  }
  await part.rename(target.path);
  return StageOutcome.written;
}

Future<bool> _matches(File file, AsrModelFile expected) async {
  if (await file.length() != expected.byteLength) return false;
  return sha256.convert(await file.readAsBytes()).toString() ==
      expected.sha256Hex;
}
