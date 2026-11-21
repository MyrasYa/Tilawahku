import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/tajwid_catalog.dart';
import '../domain/tajwid_models.dart';

abstract interface class TajwidProgressStore {
  Future<void> saveAttempt(TajwidQuizAttempt attempt);
  Future<TajwidQuizProgress> getProgress();
}

class TajwidRepository {
  TajwidRepository({TajwidProgressStore? store, DateTime Function()? clock})
    : _store = store ?? SqliteTajwidProgressStore(AppDatabase.instance),
      _clock = clock ?? DateTime.now;

  final TajwidProgressStore _store;
  final DateTime Function() _clock;
  int _idCounter = 0;

  List<TajwidCategory> getCategories() => TajwidCatalog.categories;

  List<TajwidLesson> getLessons(TajwidCategoryId categoryId) => TajwidCatalog
      .lessons
      .where((lesson) => lesson.categoryId == categoryId)
      .toList(growable: false);

  TajwidLesson? getLesson(String lessonId) {
    for (final lesson in TajwidCatalog.lessons) {
      if (lesson.id == lessonId) return lesson;
    }
    return null;
  }

  List<TajwidQuestion> createQuiz({int questionCount = 10, Random? random}) {
    if (questionCount < 1 || questionCount > TajwidCatalog.questions.length) {
      throw RangeError.range(
        questionCount,
        1,
        TajwidCatalog.questions.length,
        'questionCount',
      );
    }
    final questions = [...TajwidCatalog.questions]..shuffle(random);
    return questions.take(questionCount).toList(growable: false);
  }

  Future<TajwidQuizAttempt> recordCompletedQuiz({
    required int totalQuestions,
    required int correctAnswers,
  }) async {
    if (totalQuestions < 1 ||
        correctAnswers < 0 ||
        correctAnswers > totalQuestions) {
      throw ArgumentError('Hasil latihan tidak valid.');
    }
    final now = _clock().toUtc();
    final attempt = TajwidQuizAttempt(
      id: '${now.microsecondsSinceEpoch}-${_idCounter++}',
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      completedAt: now.toIso8601String(),
    );
    await _store.saveAttempt(attempt);
    return attempt;
  }

  Future<TajwidQuizProgress> getProgress() => _store.getProgress();
}

class SqliteTajwidProgressStore implements TajwidProgressStore {
  const SqliteTajwidProgressStore(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _database => _appDatabase.database;

  @override
  Future<void> saveAttempt(TajwidQuizAttempt attempt) async {
    final db = await _database;
    await db.insert('tajwid_quiz_attempt', {
      'id': attempt.id,
      'total_questions': attempt.totalQuestions,
      'correct_answers': attempt.correctAnswers,
      'completed_at': attempt.completedAt,
    });
  }

  @override
  Future<TajwidQuizProgress> getProgress() async {
    final db = await _database;
    final summaries = await db.rawQuery('''
      SELECT COUNT(*) AS attempts,
             COALESCE(SUM(correct_answers), 0) AS correct,
             COALESCE(SUM(total_questions), 0) AS answered,
             COALESCE(MAX(
               CAST(correct_answers AS REAL) / total_questions
             ), 0) AS best
      FROM tajwid_quiz_attempt
    ''');
    final latestRows = await db.query(
      'tajwid_quiz_attempt',
      orderBy: 'completed_at DESC, id DESC',
      limit: 1,
    );
    final summary = summaries.single;
    return TajwidQuizProgress(
      completedAttempts: summary['attempts']! as int,
      totalCorrectAnswers: summary['correct']! as int,
      totalAnsweredQuestions: summary['answered']! as int,
      bestScoreFraction: (summary['best']! as num).toDouble(),
      latestAttempt: latestRows.isEmpty
          ? null
          : TajwidQuizAttempt.fromMap(latestRows.single),
    );
  }
}
