import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/assessment_lexicon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssessmentLexicon', () {
    test('loads the bundled Uthmani-to-Imlaei map', () async {
      final map = await const AssessmentLexicon().load();

      expect(map.length, 2111);
      expect(
        map['\u0627\u0644\u0639\u0644\u0645\u064a\u0646'],
        '\u0627\u0644\u0639\u0627\u0644\u0645\u064a\u0646',
      );
      expect(
        map['\u064a\u0627\u064a\u0647\u0627'],
        '\u064a\u0627 \u0627\u064a\u0647\u0627',
      );
      expect(map.keys.where((key) => key.contains(' ')), isEmpty);
    });

    test('rejects a map that is not an object', () {
      expect(() => AssessmentLexicon.parse('[]'), throwsFormatException);
    });

    test('rejects keys that could never match a split token', () {
      expect(
        () => AssessmentLexicon.parse('{"a ": "b"}'),
        throwsFormatException,
      );
    });

    test('rejects values that are not words', () {
      expect(() => AssessmentLexicon.parse('{"a": 1}'), throwsFormatException);
      expect(
        () => AssessmentLexicon.parse('{"a": " "}'),
        throwsFormatException,
      );
    });
  });
}
