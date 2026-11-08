import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/memorization/data/memorization_repository.dart';
import 'package:tilawahku/features/memorization/domain/memorization_models.dart';
import 'package:tilawahku/features/memorization/presentation/memorization_practice_screen.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';

void main() {
  final ayahs = [
    _ayah(global: 2, surah: 1, number: 7),
    _ayah(global: 3, surah: 2, number: 1),
    _ayah(global: 4, surah: 2, number: 2),
  ];

  test('creates a validated program across a surah boundary', () async {
    final repository = MemorizationRepository(
      store: _MemoryMemorizationStore(),
      readingRepository: _MemoryReadingRepository(ayahs),
      clock: () => DateTime(2026, 11, 8, 10),
    );

    final program = await repository.createProgram(
      name: 'Lintas surah',
      scope: MemorizationScope.range,
      startGlobalAyah: 2,
      endGlobalAyah: 3,
      dailyTarget: 1,
    );

    expect(program.startGlobalAyah, 2);
    expect(program.endGlobalAyah, 3);
    expect(program.totalAyahs, 2);
    expect(program.scope, MemorizationScope.range);
  });

  test('rejects invalid range and daily target', () async {
    final repository = MemorizationRepository(
      store: _MemoryMemorizationStore(),
      readingRepository: _MemoryReadingRepository(ayahs),
    );

    await expectLater(
      repository.createProgram(
        name: '',
        scope: MemorizationScope.range,
        startGlobalAyah: 3,
        endGlobalAyah: 2,
        dailyTarget: 1,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.createProgram(
        name: '',
        scope: MemorizationScope.range,
        startGlobalAyah: 2,
        endGlobalAyah: 3,
        dailyTarget: 0,
      ),
      throwsArgumentError,
    );
  });

  test('counts a new ayah once, regardless of repeated practice', () async {
    final store = _MemoryMemorizationStore();
    final repository = MemorizationRepository(
      store: store,
      readingRepository: _MemoryReadingRepository(ayahs),
      clock: () => DateTime(2026, 11, 8, 10),
    );
    final program = await _createProgram(repository);
    final session = await repository.startSession(
      programId: program.id,
      mode: MemorizationSessionMode.recall,
    );

    expect(
      await repository.recordPractice(
        sessionId: session.id,
        globalAyahNumber: 2,
      ),
      isTrue,
    );
    expect(
      await repository.recordPractice(
        sessionId: session.id,
        globalAyahNumber: 2,
      ),
      isFalse,
    );
    expect((await repository.getDailyProgress(program)).completedNewAyahs, 1);
    expect(
      (await repository.getSessions(program.id)).single.repeatedAyahCount,
      1,
    );
  });

  test('status changes are recorded and mastered is explicit', () async {
    final store = _MemoryMemorizationStore();
    final repository = MemorizationRepository(
      store: store,
      readingRepository: _MemoryReadingRepository(ayahs),
    );
    final program = await _createProgram(repository);
    final session = await repository.startSession(
      programId: program.id,
      mode: MemorizationSessionMode.recall,
    );
    await repository.recordPractice(sessionId: session.id, globalAyahNumber: 2);

    await repository.updateStatus(
      programId: program.id,
      globalAyahNumber: 2,
      status: MemorizationStatus.mastered,
      sessionId: session.id,
    );

    expect(
      (await repository.getProgress(program.id))[2]!.status,
      MemorizationStatus.mastered,
    );
    final history = await repository.getStatusHistory(program.id);
    expect(history, hasLength(1));
    expect(history.first.oldStatus, MemorizationStatus.learning);
    expect(history.last.newStatus, MemorizationStatus.mastered);
    expect(
      (await repository.getSessionAyahs(session.id)).single.result,
      MemorizationStatus.mastered.value,
    );
  });

  testWidgets('recall mode hides ayah text until the user reveals it', (
    tester,
  ) async {
    final repository = MemorizationRepository(
      store: _MemoryMemorizationStore(),
      readingRepository: _MemoryReadingRepository(ayahs),
    );
    final program = await _createProgram(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: MemorizationPracticeScreen(
          program: program,
          repository: repository,
          readingRepository: _MemoryReadingRepository(ayahs),
          initialMode: MemorizationSessionMode.recall,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('نَصّ 2'), findsNothing);
    expect(find.text('Coba ingat ayatnya terlebih dahulu.'), findsOneWidget);
    await tester.tap(find.text('Tampilkan ayat'));
    await tester.pumpAndSettle();
    expect(find.text('نَصّ 2'), findsOneWidget);
  });

  test('sessions and progress persist across repository instances', () async {
    final store = _MemoryMemorizationStore();
    final reader = _MemoryReadingRepository(ayahs);
    final firstRepository = MemorizationRepository(
      store: store,
      readingRepository: reader,
      clock: () => DateTime(2026, 11, 8, 10),
    );
    final program = await _createProgram(firstRepository);
    final session = await firstRepository.startSession(
      programId: program.id,
      mode: MemorizationSessionMode.learn,
    );
    await firstRepository.recordPractice(
      sessionId: session.id,
      globalAyahNumber: 3,
    );
    await firstRepository.finishSession(session.id);

    final reopenedRepository = MemorizationRepository(
      store: store,
      readingRepository: reader,
      clock: () => DateTime(2026, 11, 8, 18),
    );
    expect(await reopenedRepository.getProgram(program.id), isNotNull);
    expect((await reopenedRepository.getProgress(program.id))[3], isNotNull);
    expect(
      (await reopenedRepository.getSessions(program.id)).single.completedAt,
      isNotNull,
    );
    expect(
      (await reopenedRepository.getSessionAyahs(session.id)).single.attempts,
      1,
    );
  });
}

Future<MemorizationProgram> _createProgram(MemorizationRepository repository) =>
    repository.createProgram(
      name: 'Test',
      scope: MemorizationScope.range,
      startGlobalAyah: 2,
      endGlobalAyah: 4,
      dailyTarget: 2,
    );

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

class _MemoryReadingRepository extends ReadingRepository {
  _MemoryReadingRepository(this.ayahs);

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

class _MemoryMemorizationStore implements MemorizationStore {
  final programs = <String, MemorizationProgram>{};
  final progress = <(String, int), MemorizationAyahProgress>{};
  final sessions = <String, MemorizationSession>{};
  final activities = <String, Map<int, MemorizationSessionAyah>>{};
  final history = <String, List<MemorizationStatusChange>>{};

  @override
  Future<void> createProgram(MemorizationProgram program) async {
    programs[program.id] = program;
  }

  @override
  Future<List<MemorizationProgram>> getPrograms() async =>
      programs.values.toList();

  @override
  Future<MemorizationProgram?> getProgram(String programId) async =>
      programs[programId];

  @override
  Future<void> deleteProgram(String programId) async {
    programs.remove(programId);
    progress.removeWhere((key, _) => key.$1 == programId);
    sessions.removeWhere((_, session) => session.programId == programId);
    history.remove(programId);
  }

  @override
  Future<List<MemorizationAyahProgress>> getProgress(String programId) async =>
      progress.entries
          .where((entry) => entry.key.$1 == programId)
          .map((entry) => entry.value)
          .toList();

  @override
  Future<int> getNewAyahCount(String programId, String dayKey) async => progress
      .values
      .where(
        (item) =>
            item.firstLearnedOn == dayKey &&
            _progressProgramId(item) == programId,
      )
      .length;

  final _programByAyah = <(String, int), String>{};

  String? _progressProgramId(MemorizationAyahProgress item) =>
      _programByAyah[(item.firstLearnedOn ?? '', item.globalAyahNumber)];

  @override
  Future<MemorizationSession> startSession({
    required String sessionId,
    required String programId,
    required MemorizationSessionMode mode,
    required String dayKey,
    required String startedAt,
  }) async {
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
    activities[sessionId] = {};
    return session;
  }

  @override
  Future<bool> recordPractice({
    required String sessionId,
    required int globalAyahNumber,
    required String dayKey,
    required String timestamp,
  }) async {
    final session = sessions[sessionId]!;
    final key = (session.programId, globalAyahNumber);
    final old = progress[key];
    final isNew = old?.firstLearnedOn == null;
    final newStatus = old?.status ?? MemorizationStatus.learning;
    progress[key] = MemorizationAyahProgress(
      globalAyahNumber: globalAyahNumber,
      status: newStatus,
      firstLearnedOn: old?.firstLearnedOn ?? dayKey,
      lastPracticedAt: timestamp,
    );
    _programByAyah[(dayKey, globalAyahNumber)] = session.programId;
    final sessionAyahs = activities[sessionId]!;
    final oldActivity = sessionAyahs[globalAyahNumber];
    sessionAyahs[globalAyahNumber] = MemorizationSessionAyah(
      globalAyahNumber: globalAyahNumber,
      attempts: (oldActivity?.attempts ?? 0) + 1,
      newlyLearned: oldActivity?.newlyLearned ?? isNew,
      result: oldActivity?.result,
    );
    sessions[sessionId] = MemorizationSession(
      id: session.id,
      programId: session.programId,
      mode: session.mode,
      dayKey: session.dayKey,
      startedAt: session.startedAt,
      completedAt: session.completedAt,
      newAyahCount:
          session.newAyahCount + (isNew && oldActivity == null ? 1 : 0),
      repeatedAyahCount: session.repeatedAyahCount + (isNew ? 0 : 1),
    );
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
    final key = (programId, globalAyahNumber);
    final old = progress[key];
    if (old?.status == status) return;
    history
        .putIfAbsent(programId, () => [])
        .add(
          MemorizationStatusChange(
            globalAyahNumber: globalAyahNumber,
            oldStatus: old?.status,
            newStatus: status,
            changedAt: timestamp,
          ),
        );
    progress[key] = MemorizationAyahProgress(
      globalAyahNumber: globalAyahNumber,
      status: status,
      firstLearnedOn: old?.firstLearnedOn,
      lastPracticedAt: old?.lastPracticedAt ?? timestamp,
    );
    if (old?.firstLearnedOn != null) {
      _programByAyah[(old!.firstLearnedOn!, globalAyahNumber)] = programId;
    }
    final activity = sessionId == null
        ? null
        : activities[sessionId]?[globalAyahNumber];
    if (activity != null) {
      activities[sessionId]![globalAyahNumber] = MemorizationSessionAyah(
        globalAyahNumber: activity.globalAyahNumber,
        attempts: activity.attempts,
        newlyLearned: activity.newlyLearned,
        result: status.value,
      );
    }
  }

  @override
  Future<void> finishSession(String sessionId, String timestamp) async {
    final old = sessions[sessionId]!;
    sessions[sessionId] = MemorizationSession(
      id: old.id,
      programId: old.programId,
      mode: old.mode,
      dayKey: old.dayKey,
      startedAt: old.startedAt,
      completedAt: timestamp,
      newAyahCount: old.newAyahCount,
      repeatedAyahCount: old.repeatedAyahCount,
    );
  }

  @override
  Future<List<MemorizationSession>> getSessions(String programId) async =>
      sessions.values.where((item) => item.programId == programId).toList();

  @override
  Future<List<MemorizationSessionAyah>> getSessionAyahs(
    String sessionId,
  ) async => activities[sessionId]!.values.toList();

  @override
  Future<List<MemorizationStatusChange>> getStatusHistory(
    String programId,
  ) async => history[programId] ?? const [];
}
