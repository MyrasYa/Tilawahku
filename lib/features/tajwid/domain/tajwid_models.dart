enum TajwidCategoryId {
  nunTanwin('nun_tanwin', 'Nun sukun dan tanwin'),
  mimSukun('mim_sukun', 'Mim sukun'),
  mad('mad', 'Hukum mad'),
  lam('lam', 'Hukum lam'),
  ra('ra', 'Hukum ra'),
  qalqalah('qalqalah', 'Qalqalah'),
  ghunnah('ghunnah', 'Ghunnah'),
  makharij('makharij', 'Makharijul huruf'),
  sifat('sifat', 'Sifat huruf');

  const TajwidCategoryId(this.value, this.title);

  final String value;
  final String title;
}

class TajwidCategory {
  const TajwidCategory({required this.id, required this.description});

  final TajwidCategoryId id;
  final String description;
}

class TajwidReference {
  const TajwidReference({
    required this.title,
    required this.section,
    required this.url,
  });

  final String title;
  final String section;
  final String url;
}

class TajwidAyahReference {
  const TajwidAyahReference({
    required this.surahNumber,
    required this.ayahNumber,
    required this.note,
  });

  final int surahNumber;
  final int ayahNumber;
  final String note;
}

class TajwidLesson {
  const TajwidLesson({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.definition,
    required this.condition,
    required this.readingMethod,
    required this.relatedLetters,
    required this.commonMistake,
    required this.examples,
    required this.references,
  });

  final String id;
  final TajwidCategoryId categoryId;
  final String title;
  final String definition;
  final String condition;
  final String readingMethod;
  final String relatedLetters;
  final String commonMistake;
  final List<TajwidAyahReference> examples;
  final List<TajwidReference> references;
}

enum TajwidQuestionType {
  identifyRule('Mengenali hukum'),
  identifyCategory('Mengenali kategori'),
  identifyLetters('Huruf pemicu'),
  chooseReading('Cara membaca'),
  distinguishRules('Membedakan hukum');

  const TajwidQuestionType(this.label);

  final String label;
}

class TajwidQuestion {
  const TajwidQuestion({
    required this.id,
    required this.lessonId,
    required this.type,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final String lessonId;
  final TajwidQuestionType type;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class TajwidQuizAttempt {
  const TajwidQuizAttempt({
    required this.id,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.completedAt,
  });

  final String id;
  final int totalQuestions;
  final int correctAnswers;
  final String completedAt;

  double get scoreFraction =>
      totalQuestions == 0 ? 0 : correctAnswers / totalQuestions;

  factory TajwidQuizAttempt.fromMap(Map<String, Object?> map) =>
      TajwidQuizAttempt(
        id: map['id']! as String,
        totalQuestions: map['total_questions']! as int,
        correctAnswers: map['correct_answers']! as int,
        completedAt: map['completed_at']! as String,
      );
}

class TajwidQuizProgress {
  const TajwidQuizProgress({
    required this.completedAttempts,
    required this.totalCorrectAnswers,
    required this.totalAnsweredQuestions,
    required this.bestScoreFraction,
    required this.latestAttempt,
  });

  const TajwidQuizProgress.empty()
    : completedAttempts = 0,
      totalCorrectAnswers = 0,
      totalAnsweredQuestions = 0,
      bestScoreFraction = 0,
      latestAttempt = null;

  final int completedAttempts;
  final int totalCorrectAnswers;
  final int totalAnsweredQuestions;
  final double bestScoreFraction;
  final TajwidQuizAttempt? latestAttempt;
}
