import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/core/database/database_schema.dart';

void main() {
  test('memorization schema is a forward-only additive migration', () {
    expect(DatabaseSchema.version, 6);
    expect(
      DatabaseSchema.memorizationCreateStatements,
      contains(DatabaseSchema.createMemorizationProgram),
    );
    expect(
      DatabaseSchema.createStatements,
      containsAll([
        DatabaseSchema.createMemorizationProgram,
        DatabaseSchema.createMemorizationAyahProgress,
        DatabaseSchema.createMemorizationSession,
        DatabaseSchema.createMemorizationSessionAyah,
        DatabaseSchema.createMemorizationStatusHistory,
      ]),
    );
    expect(
      DatabaseSchema.createMemorizationSession,
      contains('audio_repetition'),
    );
    expect(
      DatabaseSchema.createMemorizationStatusHistory,
      contains('mastered'),
    );
  });
}
