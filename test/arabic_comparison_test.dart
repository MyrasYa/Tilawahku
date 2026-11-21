import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/domain/arabic_comparison.dart';

void main() {
  group('compareArabicWords', () {
    test('matches Uthmani target after diacritic normalization', () {
      final result = compareArabicWords(
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        'بسم الله الرحمن الرحيم',
      );

      expect(result.assessable, isTrue);
      expect(result.matched.length, 4);
      expect(result.wordEdits, 0);
    });

    test('marks a skipped word as missing', () {
      final result = compareArabicWords(
        'بسم الله الرحمن الرحيم',
        'بسم الرحمن الرحيم',
      );

      expect(result.missing, ['الله']);
      expect(result.changed, isEmpty);
      expect(result.extra, isEmpty);
    });

    test('marks an incorrect word as changed', () {
      final result = compareArabicWords(
        'بسم الله الرحمن الرحيم',
        'بسم الحمد الرحمن الرحيم',
      );

      expect(result.changed.map((word) => [word.expected, word.recognized]), [
        ['الله', 'الحمد'],
      ]);
      expect(result.missing, isEmpty);
      expect(result.extra, isEmpty);
    });

    test('marks an inserted word as extra', () {
      final result = compareArabicWords(
        'بسم الله الرحمن الرحيم',
        'بسم الله الكريم الرحمن الرحيم',
      );

      expect(result.extra, ['الكريم']);
    });

    test('uses the model spelling map for orthographic normalization', () {
      final result = compareArabicWords(
        'الحمد لله رب العالمين',
        'الحمد لله رب العلمين',
        spellingMap: const {'العلمين': 'العالمين'},
      );

      expect(result.wordEdits, 0);
    });

    test('splits a mapped token into its separate words', () {
      const spellingMap = {'يايها': 'يا ايها'};
      final result = compareArabicWords(
        'يٰٓاَيُّهَا الَّذينَ',
        'يا ايها الذين',
        spellingMap: spellingMap,
      );

      expect(result.referenceWordCount, 3);
      expect(result.matched, ['يا', 'ايها', 'الذين']);
      expect(result.changed, isEmpty);
      expect(result.missing, isEmpty);
      expect(result.extra, isEmpty);
      expect(result.wordEdits, 0);
    });

    test('does not assess an empty or inadequate transcript', () {
      expect(
        compareArabicWords('بسم الله الرحمن الرحيم', '').assessable,
        isFalse,
      );
      expect(
        compareArabicWords('بسم الله الرحمن الرحيم', 'الله').assessable,
        isFalse,
      );
    });

    test('assesses a single-word ayah with a single-word transcript', () {
      // Surah 42:2, salah satu dari dua ayat yang hanya punya satu kata.
      final result = compareArabicWords(
        '\u0639\u0653\u0633\u0653\u0642\u0653',
        '\u0639\u0633\u0642',
      );

      expect(result.assessable, isTrue);
      expect(result.matched.length, 1);
      expect(result.wordEdits, 0);
    });

    test('reports an unscorable transcript as fully missing', () {
      final result = compareArabicWords('بسم الله الرحمن الرحيم', 'بسم');

      expect(result.assessable, isFalse);
      expect(result.missing.length, 4);
      expect(result.matched, isEmpty);
    });

    test('never lets the match percent go below zero', () {
      final result = compareArabicWords('بسم الله', 'كلمة ' * 20);

      expect(result.matchPercent, 0);
    });
  });

  group('normalizeArabic', () {
    test('drops marks, folds hamza-over-alif and collapses spaces', () {
      expect(normalizeArabic('  بِسْمِ  ٱللَّهِ  \u0640\r\n'), 'بسم الله');
    });

    test('ignores tatweel that lengthens a letter', () {
      // Token Surah 2:31; satu-satunya perbedaan dengan transkrip adalah
      // tatweel di tengah kata.
      const target =
          '\u0623\u064e\u0646\u06e2\u0628\u0650\u0640'
          '\u0654\u064f\u0648\u0646\u0650\u0649';
      const transcript = '\u0623\u0646\u0628\u0648\u0646\u0649';

      expect(normalizeArabic(target), transcript);

      final result = compareArabicWords(target, transcript);
      expect(result.matched.length, 1);
      expect(result.wordEdits, 0);
    });
  });
}
