import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tilawahku/core/database/database_schema.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Migration v8 to v9 (memorization_session)', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      );

      // Create initial v8 schema
      await db.execute(DatabaseSchema.createSurah);
      await db.execute(DatabaseSchema.createAyah);
      await db.execute(DatabaseSchema.createMemorizationProgram);

      // Seed required ayah foreign key rows
      await db.insert('surah', {
        'id': 78,
        'nama_ar': 'النبأ',
        'nama_id': 'An-Naba',
        'jumlah_ayat': 40,
      });
      await db.insert('surah', {
        'id': 114,
        'nama_ar': 'الناس',
        'nama_id': 'An-Nas',
        'jumlah_ayat': 6,
      });
      await db.insert('ayah', {
        'nomor_global': 5673,
        'surah': 78,
        'ayat': 1,
        'juz': 30,
        'halaman': 582,
        'teks_utsmani': 'عَمَّ يَتَسَآءَلُونَ',
      });
      await db.insert('ayah', {
        'nomor_global': 6236,
        'surah': 114,
        'ayat': 6,
        'juz': 30,
        'halaman': 604,
        'teks_utsmani': 'مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ',
      });

      // Create v8 memorization_session with legacy CHECK constraint (no ai_assessment)
      await db.execute('''
        CREATE TABLE memorization_session (
          id TEXT PRIMARY KEY,
          program_id TEXT NOT NULL,
          mode TEXT NOT NULL CHECK (
            mode IN ('learn', 'hide_reveal', 'recall', 'audio_repetition')
          ),
          day_key TEXT NOT NULL,
          started_at TEXT NOT NULL,
          completed_at TEXT,
          new_ayah_count INTEGER NOT NULL DEFAULT 0,
          repeated_ayah_count INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (program_id) REFERENCES memorization_program (id)
            ON DELETE CASCADE
        )
      ''');
      await db.execute(DatabaseSchema.createMemorizationSessionsIndex);
      await db.execute(DatabaseSchema.createMemorizationSessionAyah);
    });

    tearDown(() async {
      await db.close();
    });

    test('v8 rejects ai_assessment but accepts all 4 legacy modes', () async {
      // Insert program
      await db.insert('memorization_program', {
        'id': 'prog-1',
        'nama': 'Juz 30',
        'scope': 'juz',
        'start_global': 5673,
        'end_global': 6236,
        'daily_target': 3,
        'dibuat_pada': '2026-11-21T00:00:00Z',
        'diperbarui_pada': '2026-11-21T00:00:00Z',
      });

      // Insert 4 legacy modes
      final legacyModes = ['learn', 'hide_reveal', 'recall', 'audio_repetition'];
      for (final mode in legacyModes) {
        await db.insert('memorization_session', {
          'id': 'sess-$mode',
          'program_id': 'prog-1',
          'mode': mode,
          'day_key': '2026-11-21',
          'started_at': '2026-11-21T00:00:00Z',
        });
      }

      final countRows = await db.rawQuery('SELECT COUNT(*) as cnt FROM memorization_session');
      expect(Sqflite.firstIntValue(countRows), 4);

      // ai_assessment must fail under v8 constraint
      expect(
        () => db.insert('memorization_session', {
          'id': 'sess-ai',
          'program_id': 'prog-1',
          'mode': 'ai_assessment',
          'day_key': '2026-11-21',
          'started_at': '2026-11-21T00:00:00Z',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('v8 to v9 migration preserves rows, legacy modes, index, and allows ai_assessment', () async {
      await db.insert('memorization_program', {
        'id': 'prog-1',
        'nama': 'Juz 30',
        'scope': 'juz',
        'start_global': 5673,
        'end_global': 6236,
        'daily_target': 3,
        'dibuat_pada': '2026-11-21T00:00:00Z',
        'diperbarui_pada': '2026-11-21T00:00:00Z',
      });

      final legacyModes = ['learn', 'hide_reveal', 'recall', 'audio_repetition'];
      for (final mode in legacyModes) {
        await db.insert('memorization_session', {
          'id': 'sess-$mode',
          'program_id': 'prog-1',
          'mode': mode,
          'day_key': '2026-11-21',
          'started_at': '2026-11-21T00:00:00Z',
          'completed_at': '2026-11-21T00:05:00Z',
          'new_ayah_count': 2,
          'repeated_ayah_count': 3,
        });
      }

      // Execute migration
      await db.transaction((txn) async {
        final oldRows = await txn.rawQuery('SELECT COUNT(*) as cnt FROM memorization_session');
        final initialCount = Sqflite.firstIntValue(oldRows) ?? 0;

        await txn.execute('''
          CREATE TABLE memorization_session_v9 (
            id TEXT PRIMARY KEY,
            program_id TEXT NOT NULL,
            mode TEXT NOT NULL CHECK (
              mode IN ('learn', 'hide_reveal', 'recall', 'audio_repetition', 'ai_assessment')
            ),
            day_key TEXT NOT NULL,
            started_at TEXT NOT NULL,
            completed_at TEXT,
            new_ayah_count INTEGER NOT NULL DEFAULT 0,
            repeated_ayah_count INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (program_id) REFERENCES memorization_program (id)
              ON DELETE CASCADE
          )
        ''');

        await txn.execute('''
          INSERT INTO memorization_session_v9 (
            id, program_id, mode, day_key, started_at, completed_at,
            new_ayah_count, repeated_ayah_count
          )
          SELECT
            id, program_id, mode, day_key, started_at, completed_at,
            new_ayah_count, repeated_ayah_count
          FROM memorization_session
        ''');

        final newRows = await txn.rawQuery('SELECT COUNT(*) as cnt FROM memorization_session_v9');
        final migratedCount = Sqflite.firstIntValue(newRows) ?? 0;

        if (initialCount != migratedCount) {
          throw StateError(
            'Migration v8->v9 row count mismatch: '
            '$initialCount rows before, $migratedCount rows after',
          );
        }

        await txn.execute('DROP TABLE memorization_session');
        await txn.execute('ALTER TABLE memorization_session_v9 RENAME TO memorization_session');
        await txn.execute(DatabaseSchema.createMemorizationSessionsIndex);
      });

      // Verify row count preservation
      final migratedRows = await db.query('memorization_session');
      expect(migratedRows.length, 4);

      // Verify each legacy mode still exists with identical attributes
      for (final mode in legacyModes) {
        final row = migratedRows.firstWhere((r) => r['id'] == 'sess-$mode');
        expect(row['mode'], mode);
        expect(row['program_id'], 'prog-1');
        expect(row['new_ayah_count'], 2);
        expect(row['repeated_ayah_count'], 3);
      }

      // Verify ai_assessment can now be inserted
      await db.insert('memorization_session', {
        'id': 'sess-ai',
        'program_id': 'prog-1',
        'mode': 'ai_assessment',
        'day_key': '2026-11-21',
        'started_at': '2026-11-21T01:00:00Z',
      });
      final updatedRows = await db.query('memorization_session');
      expect(updatedRows.length, 5);

      // Verify invalid modes are still rejected
      expect(
        () => db.insert('memorization_session', {
          'id': 'sess-invalid',
          'program_id': 'prog-1',
          'mode': 'unsupported_mode',
          'day_key': '2026-11-21',
          'started_at': '2026-11-21T01:00:00Z',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Verify foreign key cascade
      await db.delete('memorization_program', where: 'id = ?', whereArgs: ['prog-1']);
      final afterDelete = await db.query('memorization_session');
      expect(afterDelete, isEmpty);
    });

    test('migration rolls back on failure without corrupting legacy data', () async {
      await db.insert('memorization_program', {
        'id': 'prog-1',
        'nama': 'Juz 30',
        'scope': 'juz',
        'start_global': 5673,
        'end_global': 6236,
        'daily_target': 3,
        'dibuat_pada': '2026-11-21T00:00:00Z',
        'diperbarui_pada': '2026-11-21T00:00:00Z',
      });

      await db.insert('memorization_session', {
        'id': 'sess-1',
        'program_id': 'prog-1',
        'mode': 'learn',
        'day_key': '2026-11-21',
        'started_at': '2026-11-21T00:00:00Z',
      });

      // Attempt failing transaction
      try {
        await db.transaction((txn) async {
          await txn.execute('''
            CREATE TABLE memorization_session_v9 (
              id TEXT PRIMARY KEY,
              program_id TEXT NOT NULL,
              mode TEXT NOT NULL CHECK (
                mode IN ('learn', 'hide_reveal', 'recall', 'audio_repetition', 'ai_assessment')
              ),
              day_key TEXT NOT NULL,
              started_at TEXT NOT NULL,
              completed_at TEXT,
              new_ayah_count INTEGER NOT NULL DEFAULT 0,
              repeated_ayah_count INTEGER NOT NULL DEFAULT 0
            )
          ''');

          // Deliberately simulate failure
          throw StateError('Simulated migration crash');
        });
      } catch (_) {}

      // Original table and record must still exist intact
      final rows = await db.query('memorization_session');
      expect(rows.length, 1);
      expect(rows.first['id'], 'sess-1');
    });
  });
}
