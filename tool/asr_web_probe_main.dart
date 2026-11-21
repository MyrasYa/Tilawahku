// Entrypoint verifikasi browser untuk B3 (bukan bagian dari aplikasi yang
// dikirim). Bangunannya sama persis dengan jalur produksi: database Web yang
// sama, MemorizationRepository nyata, createAsrRuntime() per-platform, dan
// layar latihan B2 berikut AssessmentPanel. Hanya navigasi bawah dan form
// pembuatan program yang dilewati supaya pengujian Chrome tidak bergantung
// pada interaksi di luar scope B3.
//
//   flutter build web --release --target tool/asr_web_probe_main.dart --output build/web_probe
import 'package:flutter/material.dart';

import 'package:tilawahku/core/database/app_database.dart';
import 'package:tilawahku/features/memorization/data/memorization_repository.dart';
import 'package:tilawahku/features/memorization/domain/memorization_models.dart';
import 'package:tilawahku/features/memorization/presentation/memorization_practice_screen.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';

const _programPrefix = 'Probe Web B3';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.ensureBundledContent();
  final readingRepository = ReadingRepository();
  final repository = MemorizationRepository(
    readingRepository: readingRepository,
  );
  // Rentang ayat diambil dari query string supaya verifikasi bisa memakai
  // sampel yang sama dengan PoC (mis. ?start=255&end=255 untuk 2:248).
  final params = Uri.base.queryParameters;
  final start = int.tryParse(params['start'] ?? '') ?? 1;
  final end = int.tryParse(params['end'] ?? '') ?? start;
  final dailyTarget = int.tryParse(params['target'] ?? '') ?? (end - start + 1);
  final programName = '$_programPrefix · $start-$end';
  MemorizationProgram? probe;
  for (final item in await repository.getPrograms()) {
    if (item.name == programName) {
      probe = item;
      break;
    }
  }
  final program =
      probe ??
      await repository.createProgram(
        name: programName,
        scope: MemorizationScope.range,
        startGlobalAyah: start,
        endGlobalAyah: end,
        dailyTarget: dailyTarget,
      );
  runApp(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: const Color(0xff176b55)),
      home: MemorizationPracticeScreen(
        program: program,
        repository: repository,
        readingRepository: readingRepository,
        initialMode: MemorizationSessionMode.learn,
      ),
    ),
  );
}
