import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/core/database/database_schema.dart';

void main() {
  test('tajwid progress uses an additive v6 schema', () {
    expect(DatabaseSchema.version, 6);
    expect(DatabaseSchema.tajwidCreateStatements, hasLength(1));
    expect(
      DatabaseSchema.createStatements,
      contains(DatabaseSchema.createTajwidQuizAttempt),
    );
    expect(
      DatabaseSchema.createTajwidQuizAttempt,
      contains('CHECK (total_questions > 0)'),
    );
    expect(
      DatabaseSchema.createTajwidQuizAttempt,
      contains('correct_answers <= total_questions'),
    );
  });
}
