import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/tajwid/data/tajwid_repository.dart';
import 'package:tilawahku/features/tajwid/domain/tajwid_catalog.dart';
import 'package:tilawahku/features/tajwid/domain/tajwid_models.dart';

void main() {
  test(
    'catalog covers all requested learning categories with source links',
    () {
      expect(
        TajwidCatalog.categories.map((category) => category.id).toSet(),
        containsAll(TajwidCategoryId.values),
      );
      expect(TajwidCatalog.lessons, isNotEmpty);
      for (final lesson in TajwidCatalog.lessons) {
        expect(lesson.title, isNotEmpty, reason: lesson.id);
        expect(lesson.definition, isNotEmpty, reason: lesson.id);
        expect(lesson.condition, isNotEmpty, reason: lesson.id);
        expect(lesson.readingMethod, isNotEmpty, reason: lesson.id);
        expect(lesson.relatedLetters, isNotEmpty, reason: lesson.id);
        expect(lesson.commonMistake, isNotEmpty, reason: lesson.id);
        expect(lesson.examples, isNotEmpty, reason: lesson.id);
        expect(lesson.references, isNotEmpty, reason: lesson.id);
        for (final example in lesson.examples) {
          expect(example.surahNumber, inInclusiveRange(1, 114));
          expect(example.ayahNumber, greaterThan(0));
        }
        for (final reference in lesson.references) {
          expect(reference.title, isNotEmpty);
          expect(reference.section, isNotEmpty);
          expect(Uri.tryParse(reference.url)?.hasScheme, isTrue);
        }
      }
    },
  );

  test('quiz questions are unambiguous and cover requested question forms', () {
    expect(
      TajwidCatalog.questions.map((question) => question.type).toSet(),
      containsAll(TajwidQuestionType.values),
    );
    for (final question in TajwidCatalog.questions) {
      expect(
        question.options.length,
        greaterThanOrEqualTo(2),
        reason: question.id,
      );
      expect(
        question.correctIndex,
        inInclusiveRange(0, question.options.length - 1),
        reason: question.id,
      );
      expect(question.explanation, isNotEmpty, reason: question.id);
      expect(
        TajwidCatalog.lessons.any((lesson) => lesson.id == question.lessonId),
        isTrue,
        reason: question.id,
      );
    }
  });

  test('repository returns categories, lessons, and bounded quiz sets', () {
    final repository = TajwidRepository(store: _MemoryTajwidProgressStore());

    expect(
      repository.getCategories(),
      hasLength(TajwidCategoryId.values.length),
    );
    expect(repository.getLessons(TajwidCategoryId.nunTanwin), hasLength(5));
    expect(repository.getLesson('idgham-bighunnah')?.title, 'Idgham Bighunnah');
    expect(repository.getLesson('unknown'), isNull);
    expect(repository.createQuiz(questionCount: 8), hasLength(8));
    expect(
      () => repository.createQuiz(
        questionCount: TajwidCatalog.questions.length + 1,
      ),
      throwsRangeError,
    );
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
    final latest = attempts.last;
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
      latestAttempt: latest,
    );
  }
}
