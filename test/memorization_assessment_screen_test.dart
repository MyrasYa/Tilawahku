import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/core/database/database_schema.dart';
import 'package:tilawahku/features/assessment/data/asr_runtime.dart';
import 'package:tilawahku/features/assessment/data/asr_runtime_factory.dart';
import 'package:tilawahku/features/assessment/data/recitation_recorder.dart';
import 'package:tilawahku/features/assessment/domain/recitation_audio.dart';
import 'package:tilawahku/features/assessment/presentation/recitation_assessment_controller.dart';
import 'package:tilawahku/features/memorization/data/memorization_repository.dart';
import 'package:tilawahku/features/memorization/domain/memorization_models.dart';
import 'package:tilawahku/features/memorization/presentation/memorization_practice_screen.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';

/// Teks latihan memakai bentuk yang sudah dinormalisasi engine B1, sehingga
/// 'نص 2' adalah transkrip ASR yang identik dengan ayat global 2.
const _spokenAyah2 = 'نص 2';
const _spokenAyah3 = 'نص 3';

void main() {
  testWidgets('Mode Latihan keeps the ayah text visible while recording', (
    tester,
  ) async {
    final capture = _FakeCapture();
    final controller = _controller(_FakeRuntime(_spokenAyah2), capture);
    await _pumpPracticeScreen(tester, controller: controller);

    expect(
      find.text('Teks ayat tetap terlihat selama rekaman.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Rekam bacaan'));
    await tester.pumpAndSettle();

    expect(controller.phase, AssessmentPhase.recording);
    expect(find.text('Merekam · baca sambil melihat ayat'), findsOneWidget);
    expect(find.text('نَصّ 2'), findsOneWidget);
    expect(find.text('Tampilkan ayat'), findsNothing);
    controller.dispose();
  });

  testWidgets(
    'Mode Setoran hides the ayah text and reveals it with the result',
    (tester) async {
      final capture = _FakeCapture();
      final controller = _controller(_FakeRuntime(_spokenAyah2), capture);
      await _pumpPracticeScreen(tester, controller: controller);

      await tester.tap(find.text('Mode Setoran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rekam bacaan'));
      await tester.pumpAndSettle();

      expect(controller.mode, AssessmentMode.setoran);
      expect(controller.phase, AssessmentPhase.recording);
      expect(find.text('Merekam · baca dari hafalan'), findsOneWidget);
      expect(find.text('نَصّ 2'), findsNothing);
      expect(
        find.text('Teks ayat disembunyikan selama Mode Setoran merekam.'),
        findsOneWidget,
      );
      expect(find.textContaining('Kesesuaian kata'), findsNothing);

      await tester.tap(find.text('Berhenti & nilai'));
      await tester.pumpAndSettle();

      expect(controller.phase, AssessmentPhase.scored);
      expect(find.text('نَصّ 2'), findsOneWidget);
      expect(
        find.textContaining(
          'Kesesuaian kata: 100.0 % (0 perbaikan dari 2 kata)',
        ),
        findsOneWidget,
      );
      expect(find.text('Cocok 2'), findsOneWidget);
      expect(find.text('Transkrip hasil pengenalan'), findsOneWidget);
      controller.dispose();
    },
  );

  testWidgets('assesses the ayah that the Memorization program selected', (
    tester,
  ) async {
    final store = _RecordingStore();
    final runtime = _FakeRuntime(_spokenAyah3);
    final controller = _controller(runtime, _FakeCapture());
    await _pumpPracticeScreen(tester, store: store, controller: controller);

    await tester.tap(find.text('Berikutnya'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ayat 2 dari 3'), findsOneWidget);

    await tester.tap(find.text('Rekam bacaan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berhenti & nilai'));
    await tester.pumpAndSettle();

    expect(runtime.recognized, hasLength(1));
    expect(find.text('نَصّ 3'), findsOneWidget);
    expect(
      find.textContaining('Kesesuaian kata: 100.0 % (0 perbaikan dari 2 kata)'),
      findsOneWidget,
    );
    expect(store.recordedAyahs, [2, 3]);
    controller.dispose();
  });

  testWidgets('moving to another ayah cancels an open recording', (
    tester,
  ) async {
    final capture = _FakeCapture();
    final controller = _controller(_FakeRuntime(_spokenAyah2), capture);
    await _pumpPracticeScreen(tester, controller: controller);

    await tester.tap(find.text('Mode Setoran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rekam bacaan'));
    await tester.pumpAndSettle();
    expect(capture.cancelCalls, 0);

    await tester.tap(find.text('Berikutnya'));
    await tester.pumpAndSettle();

    expect(capture.cancelCalls, 1);
    expect(controller.attempt, isNull);
    expect(controller.phase, AssessmentPhase.idle);
    expect(find.textContaining('Kesesuaian kata'), findsNothing);
    expect(find.text('نَصّ 3'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('shows an unavailable state instead of a fake result', (
    tester,
  ) async {
    expect(createAsrRuntime(), isNull);
    final store = _RecordingStore();
    await _pumpPracticeScreen(tester, store: store);

    expect(find.text('belum tersedia'), findsOneWidget);
    expect(find.text('Belum tersedia di platform ini'), findsOneWidget);
    expect(find.textContaining('Kesesuaian kata'), findsNothing);
    expect(find.text('Rekam ulang'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Rekam bacaan'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Mode Setoran'));
    await tester.pumpAndSettle();
    expect(find.text('نَصّ 2'), findsOneWidget);
    expect(store.recordPracticeCalls, 1);
    expect(store.updateStatusCalls, 0);
  });

  testWidgets('leaving the page releases the microphone and runtime', (
    tester,
  ) async {
    final capture = _FakeCapture();
    final runtime = _FakeRuntime(_spokenAyah2);
    final controller = _controller(runtime, capture);
    await _pumpPracticeScreen(tester, controller: controller);

    await tester.tap(find.text('Rekam bacaan'));
    await tester.pumpAndSettle();
    expect(capture.startCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await controller.released;

    expect(capture.disposeCalls, 1);
    expect(runtime.disposeCalls, 1);
  });

  testWidgets('assessment adds no memorization writes and no schema change', (
    tester,
  ) async {
    expect(DatabaseSchema.version, 6);
    expect(MemorizationSessionMode.values, hasLength(4));
    expect(DatabaseSchema.createStatements, hasLength(22));
    expect(
      DatabaseSchema.createStatements.join(),
      isNot(contains('assessment')),
    );
    expect(
      DatabaseSchema.createMemorizationSession,
      contains("'learn', 'hide_reveal', 'recall', 'audio_repetition'"),
    );

    final store = _RecordingStore();
    final controller = _controller(_FakeRuntime(_spokenAyah2), _FakeCapture());
    await _pumpPracticeScreen(tester, store: store, controller: controller);

    await tester.tap(find.text('Rekam bacaan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berhenti & nilai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rekam ulang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berhenti & nilai'));
    await tester.pumpAndSettle();

    expect(store.startSessionCalls, 1);
    expect(store.recordPracticeCalls, 1);
    expect(store.updateStatusCalls, 0);
    expect(store.finishSessionCalls, 0);
    controller.dispose();
  });
}

RecitationAssessmentController _controller(
  AsrRuntime runtime,
  RecitationCapture capture,
) => RecitationAssessmentController(
  runtime: runtime,
  createCapture: () => capture,
  loadSpellingMap: () async => const {},
);

Future<void> _pumpPracticeScreen(
  WidgetTester tester, {
  _RecordingStore? store,
  RecitationAssessmentController? controller,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final memorizationStore = store ?? _RecordingStore();
  final readingRepository = _FakeReadingRepository(_ayahs);
  final program = MemorizationProgram(
    id: 'program-1',
    name: 'Program uji',
    scope: MemorizationScope.range,
    startGlobalAyah: 2,
    endGlobalAyah: 4,
    dailyTarget: 2,
    createdAt: '2026-11-08T03:00:00.000Z',
    updatedAt: '2026-11-08T03:00:00.000Z',
  );
  final repository = MemorizationRepository(
    store: memorizationStore,
    readingRepository: readingRepository,
    clock: () => DateTime(2026, 11, 8, 10),
  );
  final screen = MemorizationPracticeScreen(
    program: program,
    repository: repository,
    readingRepository: readingRepository,
    initialMode: MemorizationSessionMode.learn,
    assessment: controller,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => screen)),
              child: const Text('buka latihan'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka latihan'));
  await tester.pumpAndSettle();
}

final _ayahs = [
  _ayah(global: 2, surah: 1, number: 7),
  _ayah(global: 3, surah: 2, number: 1),
  _ayah(global: 4, surah: 2, number: 2),
];

AyahEntry _ayah({
  required int global,
  required int surah,
  required int number,
}) => AyahEntry(
  globalNumber: global,
  surahNumber: surah,
  ayahNumber: number,
  juzNumber: 1,
  pageNumber: 1,
  uthmaniText: 'نَصّ $global',
  indonesianTranslation: 'Terjemahan $global',
  surahNameIndonesian: 'Surah $surah',
);

class _FakeReadingRepository extends ReadingRepository {
  _FakeReadingRepository(this.ayahs);

  final List<AyahEntry> ayahs;

  @override
  Future<List<AyahEntry>> getAyahsBetweenGlobalNumbers(
    int startGlobalNumber,
    int endGlobalNumber,
  ) async {
    if (startGlobalNumber > endGlobalNumber) {
      throw RangeError('Rentang tidak valid');
    }
    final result = ayahs
        .where(
          (ayah) =>
              ayah.globalNumber >= startGlobalNumber &&
              ayah.globalNumber <= endGlobalNumber,
        )
        .toList();
    if (result.length != endGlobalNumber - startGlobalNumber + 1) {
      throw StateError('Data ayat tidak lengkap');
    }
    return result;
  }
}

class _RecordingStore implements MemorizationStore {
  final progress = <int, MemorizationAyahProgress>{};
  final sessions = <String, MemorizationSession>{};
  final recordedAyahs = <int>[];

  int startSessionCalls = 0;
  int recordPracticeCalls = 0;
  int updateStatusCalls = 0;
  int finishSessionCalls = 0;

  @override
  Future<void> createProgram(MemorizationProgram program) async {}

  @override
  Future<List<MemorizationProgram>> getPrograms() async => const [];

  @override
  Future<MemorizationProgram?> getProgram(String programId) async => null;

  @override
  Future<void> deleteProgram(String programId) async {}

  @override
  Future<List<MemorizationAyahProgress>> getProgress(String programId) async =>
      progress.values.toList();

  @override
  Future<int> getNewAyahCount(String programId, String dayKey) async =>
      progress.length;

  @override
  Future<MemorizationSession> startSession({
    required String sessionId,
    required String programId,
    required MemorizationSessionMode mode,
    required String dayKey,
    required String startedAt,
  }) async {
    startSessionCalls++;
    final session = MemorizationSession(
      id: sessionId,
      programId: programId,
      mode: mode,
      dayKey: dayKey,
      startedAt: startedAt,
      completedAt: null,
      newAyahCount: 0,
      repeatedAyahCount: 0,
    );
    sessions[sessionId] = session;
    return session;
  }

  @override
  Future<bool> recordPractice({
    required String sessionId,
    required int globalAyahNumber,
    required String dayKey,
    required String timestamp,
    String? result,
  }) async {
    recordPracticeCalls++;
    final isNew = !progress.containsKey(globalAyahNumber);
    recordedAyahs.add(globalAyahNumber);
    if (isNew) {
      progress[globalAyahNumber] = MemorizationAyahProgress(
        globalAyahNumber: globalAyahNumber,
        status: MemorizationStatus.learning,
        firstLearnedOn: dayKey,
        lastPracticedAt: timestamp,
      );
    }
    return isNew;
  }

  @override
  Future<void> updateStatus({
    required String programId,
    required int globalAyahNumber,
    required MemorizationStatus status,
    required String timestamp,
    String? sessionId,
  }) async {
    updateStatusCalls++;
    progress[globalAyahNumber] = MemorizationAyahProgress(
      globalAyahNumber: globalAyahNumber,
      status: status,
      firstLearnedOn: progress[globalAyahNumber]?.firstLearnedOn,
      lastPracticedAt: timestamp,
    );
  }

  @override
  Future<void> finishSession(String sessionId, String timestamp) async {
    finishSessionCalls++;
  }

  @override
  Future<List<MemorizationSession>> getSessions(String programId) async =>
      sessions.values.toList();

  @override
  Future<List<MemorizationSessionAyah>> getSessionAyahs(
    String sessionId,
  ) async => const [];

  @override
  Future<List<MemorizationStatusChange>> getStatusHistory(
    String programId,
  ) async => const [];
}

final _twoSeconds = RecitationAudio(Float32List(32000));

class _FakeRuntime implements AsrRuntime {
  _FakeRuntime(this.transcript);

  final String transcript;
  final recognized = <RecitationAudio>[];
  int disposeCalls = 0;

  @override
  Future<void> prepare({AsrProgress? onProgress}) async {}

  @override
  Future<String> recognize(RecitationAudio audio) async {
    recognized.add(audio);
    return transcript;
  }

  @override
  void dispose() => disposeCalls++;
}

class _FakeCapture implements RecitationCapture {
  int startCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<RecitationAudio> stop() async => _twoSeconds;

  @override
  Future<void> cancel() async => cancelCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}
