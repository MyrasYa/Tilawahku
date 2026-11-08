import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/tajwid/data/tajwid_repository.dart';
import 'package:tilawahku/features/tajwid/domain/tajwid_models.dart';

void main() {
  test('records offline quiz attempts and derives progress', () async {
    final store = _MemoryTajwidProgressStore();
    final repository = TajwidRepository(
      store: store,
      clock: () => DateTime(2026, 11, 8, 12),
    );

    final first = await repository.recordCompletedQuiz(
      totalQuestions: 10,
      correctAnswers: 7,
    );
    final second = await repository.recordCompletedQuiz(
      totalQuestions: 8,
      correctAnswers: 8,
    );
    final progress = await repository.getProgress();

    expect(first.scoreFraction, 0.7);
    expect(second.scoreFraction, 1);
    expect(progress.completedAttempts, 2);
    expect(progress.totalCorrectAnswers, 15);
    expect(progress.totalAnsweredQuestions, 18);
    expect(progress.bestScoreFraction, 1);
    expect(progress.latestAttempt?.id, second.id);
  });

  test('rejects invalid quiz result without writing it', () async {
    final store = _MemoryTajwidProgressStore();
    final repository = TajwidRepository(store: store);

    await expectLater(
      repository.recordCompletedQuiz(totalQuestions: 0, correctAnswers: 0),
      throwsArgumentError,
    );
    await expectLater(
      repository.recordCompletedQuiz(totalQuestions: 3, correctAnswers: 4),
      throwsArgumentError,
    );
    expect(store.attempts, isEmpty);
  });

  test('attempt history persists when repository is reopened', () async {
    final store = _MemoryTajwidProgressStore();
    final repository = TajwidRepository(store: store);
    await repository.recordCompletedQuiz(totalQuestions: 5, correctAnswers: 4);

    final reopened = TajwidRepository(store: store);

    expect((await reopened.getProgress()).completedAttempts, 1);
    expect((await reopened.getProgress()).totalCorrectAnswers, 4);
  });
}

class _MemoryTajwidProgressStore implements TajwidProgressStore {
  final attempts = <TajwidQuizAttempt>[];

  @override
  Future<void> saveAttempt(TajwidQuizAttempt attempt) async {
    attempts.add(attempt);
  }

  @override
  Future<TajwidQuizProgress> getProgress() async {
    if (attempts.isEmpty) return const TajwidQuizProgress.empty();
    return TajwidQuizProgress(
      completedAttempts: attempts.length,
      totalCorrectAnswers: attempts.fold(
        0,
        (total, attempt) => total + attempt.correctAnswers,
      ),
      totalAnsweredQuestions: attempts.fold(
        0,
        (total, attempt) => total + attempt.totalQuestions,
      ),
      bestScoreFraction: attempts
          .map((attempt) => attempt.scoreFraction)
          .reduce((first, second) => first > second ? first : second),
      latestAttempt: attempts.last,
    );
  }
}
