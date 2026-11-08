import 'dart:collection';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../reading/data/reading_repository.dart';
import '../domain/memorization_models.dart';

abstract interface class MemorizationStore {
  Future<void> createProgram(MemorizationProgram program);
  Future<List<MemorizationProgram>> getPrograms();
  Future<MemorizationProgram?> getProgram(String programId);
  Future<void> deleteProgram(String programId);
  Future<List<MemorizationAyahProgress>> getProgress(String programId);
  Future<int> getNewAyahCount(String programId, String dayKey);
  Future<MemorizationSession> startSession({
    required String sessionId,
    required String programId,
    required MemorizationSessionMode mode,
    required String dayKey,
    required String startedAt,
  });
  Future<bool> recordPractice({
    required String sessionId,
    required int globalAyahNumber,
    required String dayKey,
    required String timestamp,
  });
  Future<void> updateStatus({
    required String programId,
    required int globalAyahNumber,
    required MemorizationStatus status,
    required String timestamp,
    String? sessionId,
  });
  Future<void> finishSession(String sessionId, String timestamp);
  Future<List<MemorizationSession>> getSessions(String programId);
  Future<List<MemorizationSessionAyah>> getSessionAyahs(String sessionId);
  Future<List<MemorizationStatusChange>> getStatusHistory(String programId);
}

class MemorizationRepository {
  MemorizationRepository({
    MemorizationStore? store,
    ReadingRepository? readingRepository,
    DateTime Function()? clock,
  }) : _store = store ?? SqliteMemorizationStore(AppDatabase.instance),
       _readingRepository = readingRepository ?? ReadingRepository(),
       _clock = clock ?? DateTime.now;

  final MemorizationStore _store;
  final ReadingRepository _readingRepository;
  final DateTime Function() _clock;
  int _idCounter = 0;

  Future<MemorizationProgram> createProgram({
    required String name,
    required MemorizationScope scope,
    required int startGlobalAyah,
    required int endGlobalAyah,
    required int dailyTarget,
  }) async {
    if (startGlobalAyah < 1 ||
        endGlobalAyah < startGlobalAyah ||
        dailyTarget < 1) {
      throw ArgumentError('Rentang ayat atau target harian tidak valid.');
    }

    final ayahs = await _readingRepository.getAyahsBetweenGlobalNumbers(
      startGlobalAyah,
      endGlobalAyah,
    );
    if (ayahs.length != endGlobalAyah - startGlobalAyah + 1) {
      throw StateError('Rentang ayat tidak lengkap pada data Al-Qur’an.');
    }

    final now = _clock();
    final timestamp = now.toUtc().toIso8601String();
    final nameToSave = name.trim().isEmpty
        ? 'Hafalan ${ayahs.first.surahNameIndonesian ?? 'Al-Qur’an'}'
        : name.trim();
    final program = MemorizationProgram(
      id: _newId(now),
      name: nameToSave,
      scope: scope,
      startGlobalAyah: startGlobalAyah,
      endGlobalAyah: endGlobalAyah,
      dailyTarget: dailyTarget,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await _store.createProgram(program);
    return program;
  }

  Future<List<MemorizationProgram>> getPrograms() => _store.getPrograms();

  Future<MemorizationProgram?> getProgram(String programId) =>
      _store.getProgram(programId);

  Future<void> deleteProgram(String programId) =>
      _store.deleteProgram(programId);

  Future<List<AyahEntry>> getProgramAyahs(MemorizationProgram program) =>
      _readingRepository.getAyahsBetweenGlobalNumbers(
        program.startGlobalAyah,
        program.endGlobalAyah,
      );

  Future<Map<int, MemorizationAyahProgress>> getProgress(
    String programId,
  ) async {
    final progress = await _store.getProgress(programId);
    return {for (final item in progress) item.globalAyahNumber: item};
  }

  Future<DailyMemorizationProgress> getDailyProgress(
    MemorizationProgram program, {
    DateTime? date,
  }) async {
    final dayKey = _dayKey(date ?? _clock());
    final newAyahs = await _store.getNewAyahCount(program.id, dayKey);
    return DailyMemorizationProgress(
      completedNewAyahs: newAyahs,
      dailyTarget: program.dailyTarget,
    );
  }

  Future<MemorizationSession> startSession({
    required String programId,
    required MemorizationSessionMode mode,
  }) async {
    final now = _clock();
    return _store.startSession(
      sessionId: _newId(now),
      programId: programId,
      mode: mode,
      dayKey: _dayKey(now),
      startedAt: now.toUtc().toIso8601String(),
    );
  }

  Future<bool> recordPractice({
    required String sessionId,
    required int globalAyahNumber,
  }) {
    final now = _clock();
    return _store.recordPractice(
      sessionId: sessionId,
      globalAyahNumber: globalAyahNumber,
      dayKey: _dayKey(now),
      timestamp: now.toUtc().toIso8601String(),
    );
  }

  Future<void> updateStatus({
    required String programId,
    required int globalAyahNumber,
    required MemorizationStatus status,
    String? sessionId,
  }) => _store.updateStatus(
    programId: programId,
    globalAyahNumber: globalAyahNumber,
    status: status,
    timestamp: _clock().toUtc().toIso8601String(),
    sessionId: sessionId,
  );

  Future<void> finishSession(String sessionId) =>
      _store.finishSession(sessionId, _clock().toUtc().toIso8601String());

  Future<List<MemorizationSession>> getSessions(String programId) =>
      _store.getSessions(programId);

  Future<List<MemorizationSessionAyah>> getSessionAyahs(String sessionId) =>
      _store.getSessionAyahs(sessionId);

  Future<List<MemorizationStatusChange>> getStatusHistory(String programId) =>
      _store.getStatusHistory(programId);

  String _newId(DateTime now) =>
      '${now.microsecondsSinceEpoch}-${_idCounter++}';

  static String _dayKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class SqliteMemorizationStore implements MemorizationStore {
  const SqliteMemorizationStore(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _database => _appDatabase.database;

  @override
  Future<void> createProgram(MemorizationProgram program) async {
    final db = await _database;
    await db.insert('memorization_program', {
      'id': program.id,
      'nama': program.name,
      'scope': program.scope.value,
      'start_global': program.startGlobalAyah,
      'end_global': program.endGlobalAyah,
      'daily_target': program.dailyTarget,
      'dibuat_pada': program.createdAt,
      'diperbarui_pada': program.updatedAt,
    });
  }

  @override
  Future<List<MemorizationProgram>> getPrograms() async {
    final db = await _database;
    final rows = await db.query(
      'memorization_program',
      orderBy: 'diperbarui_pada DESC',
    );
    return rows.map(MemorizationProgram.fromMap).toList(growable: false);
  }

  @override
  Future<MemorizationProgram?> getProgram(String programId) async {
    final db = await _database;
    final rows = await db.query(
      'memorization_program',
      where: 'id = ?',
      whereArgs: [programId],
      limit: 1,
    );
    return rows.isEmpty ? null : MemorizationProgram.fromMap(rows.single);
  }

  @override
  Future<void> deleteProgram(String programId) async {
    final db = await _database;
    await db.delete(
      'memorization_program',
      where: 'id = ?',
      whereArgs: [programId],
    );
  }

  @override
  Future<List<MemorizationAyahProgress>> getProgress(String programId) async {
    final db = await _database;
    final rows = await db.query(
      'memorization_ayah_progress',
      where: 'program_id = ?',
      whereArgs: [programId],
      orderBy: 'nomor_global',
    );
    return rows.map(MemorizationAyahProgress.fromMap).toList(growable: false);
  }

  @override
  Future<int> getNewAyahCount(String programId, String dayKey) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM memorization_ayah_progress '
      'WHERE program_id = ? AND first_learned_on = ?',
      [programId, dayKey],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<MemorizationSession> startSession({
    required String sessionId,
    required String programId,
    required MemorizationSessionMode mode,
    required String dayKey,
    required String startedAt,
  }) async {
    final db = await _database;
    await db.insert('memorization_session', {
      'id': sessionId,
      'program_id': programId,
      'mode': mode.value,
      'day_key': dayKey,
      'started_at': startedAt,
    });
    return MemorizationSession(
      id: sessionId,
      programId: programId,
      mode: mode,
      dayKey: dayKey,
      startedAt: startedAt,
      completedAt: null,
      newAyahCount: 0,
      repeatedAyahCount: 0,
    );
  }

  @override
  Future<bool> recordPractice({
    required String sessionId,
    required int globalAyahNumber,
    required String dayKey,
    required String timestamp,
  }) async {
    final db = await _database;
    return db.transaction((transaction) async {
      final sessions = await transaction.query(
        'memorization_session',
        columns: ['program_id'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isEmpty) throw StateError('Sesi hafalan tidak ditemukan.');
      final programId = sessions.single['program_id']! as String;
      final programRows = await transaction.query(
        'memorization_program',
        columns: ['start_global', 'end_global'],
        where: 'id = ?',
        whereArgs: [programId],
        limit: 1,
      );
      if (programRows.isEmpty) throw StateError('Program hafalan tidak ada.');
      final start = programRows.single['start_global']! as int;
      final end = programRows.single['end_global']! as int;
      if (globalAyahNumber < start || globalAyahNumber > end) {
        throw RangeError('Ayat berada di luar program hafalan.');
      }
      final progressRows = await transaction.query(
        'memorization_ayah_progress',
        where: 'program_id = ? AND nomor_global = ?',
        whereArgs: [programId, globalAyahNumber],
        limit: 1,
      );
      final progress = progressRows.firstOrNull;
      final oldStatus = progress?['status'] as String?;
      final firstLearnedOn = progress?['first_learned_on'] as String?;
      final isNewAyah = firstLearnedOn == null;
      final currentStatus =
          oldStatus == null || oldStatus == MemorizationStatus.notStarted.value
          ? MemorizationStatus.learning.value
          : oldStatus;
      if (oldStatus != currentStatus) {
        await transaction.insert('memorization_status_history', {
          'program_id': programId,
          'nomor_global': globalAyahNumber,
          'session_id': sessionId,
          'old_status': oldStatus,
          'new_status': currentStatus,
          'changed_at': timestamp,
        });
      }
      await transaction.insert('memorization_ayah_progress', {
        'program_id': programId,
        'nomor_global': globalAyahNumber,
        'status': currentStatus,
        'first_learned_on': firstLearnedOn ?? dayKey,
        'last_practiced_at': timestamp,
        'diperbarui_pada': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final activityRows = await transaction.query(
        'memorization_session_ayah',
        where: 'session_id = ? AND nomor_global = ?',
        whereArgs: [sessionId, globalAyahNumber],
        limit: 1,
      );
      final activity = activityRows.firstOrNull;
      final firstInSession = activity == null;
      final attempts = (activity?['attempts'] as int? ?? 0) + 1;
      final newlyLearned =
          isNewAyah || ((activity?['newly_learned'] as int? ?? 0) == 1);
      await transaction.insert('memorization_session_ayah', {
        'session_id': sessionId,
        'nomor_global': globalAyahNumber,
        'attempts': attempts,
        'newly_learned': newlyLearned ? 1 : 0,
        'first_practiced_at': activity?['first_practiced_at'] ?? timestamp,
        'last_practiced_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (firstInSession && isNewAyah) {
        await transaction.rawUpdate(
          'UPDATE memorization_session SET new_ayah_count = '
          'new_ayah_count + 1 WHERE id = ?',
          [sessionId],
        );
      } else {
        await transaction.rawUpdate(
          'UPDATE memorization_session SET repeated_ayah_count = '
          'repeated_ayah_count + 1 WHERE id = ?',
          [sessionId],
        );
      }
      return isNewAyah;
    });
  }

  @override
  Future<void> updateStatus({
    required String programId,
    required int globalAyahNumber,
    required MemorizationStatus status,
    required String timestamp,
    String? sessionId,
  }) async {
    final db = await _database;
    await db.transaction((transaction) async {
      final programRows = await transaction.query(
        'memorization_program',
        columns: ['start_global', 'end_global'],
        where: 'id = ?',
        whereArgs: [programId],
        limit: 1,
      );
      if (programRows.isEmpty) throw StateError('Program hafalan tidak ada.');
      final start = programRows.single['start_global']! as int;
      final end = programRows.single['end_global']! as int;
      if (globalAyahNumber < start || globalAyahNumber > end) {
        throw RangeError('Ayat berada di luar program hafalan.');
      }
      final rows = await transaction.query(
        'memorization_ayah_progress',
        where: 'program_id = ? AND nomor_global = ?',
        whereArgs: [programId, globalAyahNumber],
        limit: 1,
      );
      final existing = rows.firstOrNull;
      final oldStatus = existing?['status'] as String?;
      if (oldStatus == status.value) return;
      if (sessionId != null) {
        final sessionRows = await transaction.query(
          'memorization_session',
          columns: ['program_id'],
          where: 'id = ?',
          whereArgs: [sessionId],
          limit: 1,
        );
        if (sessionRows.isEmpty ||
            sessionRows.single['program_id'] != programId) {
          throw StateError('Sesi tidak sesuai dengan program hafalan.');
        }
      }
      await transaction.insert('memorization_status_history', {
        'program_id': programId,
        'nomor_global': globalAyahNumber,
        'session_id': sessionId,
        'old_status': oldStatus,
        'new_status': status.value,
        'changed_at': timestamp,
      });
      await transaction.insert('memorization_ayah_progress', {
        'program_id': programId,
        'nomor_global': globalAyahNumber,
        'status': status.value,
        'first_learned_on': existing?['first_learned_on'],
        'last_practiced_at': existing?['last_practiced_at'] ?? timestamp,
        'diperbarui_pada': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (sessionId != null) {
        await transaction.update(
          'memorization_session_ayah',
          {'result': status.value},
          where: 'session_id = ? AND nomor_global = ?',
          whereArgs: [sessionId, globalAyahNumber],
        );
      }
    });
  }

  @override
  Future<void> finishSession(String sessionId, String timestamp) async {
    final db = await _database;
    await db.update(
      'memorization_session',
      {'completed_at': timestamp},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<List<MemorizationSession>> getSessions(String programId) async {
    final db = await _database;
    final rows = await db.query(
      'memorization_session',
      where: 'program_id = ?',
      whereArgs: [programId],
      orderBy: 'started_at DESC',
    );
    return rows.map(MemorizationSession.fromMap).toList(growable: false);
  }

  @override
  Future<List<MemorizationSessionAyah>> getSessionAyahs(
    String sessionId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'memorization_session_ayah',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'nomor_global',
    );
    return rows.map(MemorizationSessionAyah.fromMap).toList(growable: false);
  }

  @override
  Future<List<MemorizationStatusChange>> getStatusHistory(
    String programId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'memorization_status_history',
      where: 'program_id = ?',
      whereArgs: [programId],
      orderBy: 'changed_at DESC, id DESC',
    );
    return rows.map(MemorizationStatusChange.fromMap).toList(growable: false);
  }
}
