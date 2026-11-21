import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    final database = _database;
    if (database != null) {
      return database;
    }

    final databasePath = await getDatabasesPath();
    final filePath = path.join(databasePath, 'tilawahku.db');
    final databaseFile = File(filePath);
    if (!await databaseFile.exists()) {
      final bundledDatabase = await rootBundle.load(
        'assets/data/tilawahku_content.db',
      );
      await databaseFile.parent.create(recursive: true);
      await databaseFile.writeAsBytes(
        bundledDatabase.buffer.asUint8List(
          bundledDatabase.offsetInBytes,
          bundledDatabase.lengthInBytes,
        ),
        flush: true,
      );
    }
    final openedDatabase = await openDatabase(
      filePath,
      version: DatabaseSchema.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (final statement in DatabaseSchema.createStatements) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(DatabaseSchema.createAudioPackage);
          await db.execute(DatabaseSchema.createContentMetadata);
        }
        if (oldVersion < 4) {
          await db.execute(DatabaseSchema.createTransliterasi);
        }
        if (oldVersion < 5) {
          for (final statement in DatabaseSchema.memorizationCreateStatements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 6) {
          for (final statement in DatabaseSchema.tajwidCreateStatements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 7) {
          for (final statement in DatabaseSchema.prayerCreateStatements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 8) {
          for (final statement
              in DatabaseSchema.hijriCalendarCreateStatements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 9) {
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
        }
      },
      onOpen: (db) => _ensureBundledContent(db, filePath),
    );
    _database = openedDatabase;
    return openedDatabase;
  }

  Future<void> _ensureBundledContent(Database db, String databasePath) async {
    final installedAyahs = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ayah'),
    );
    final installedTranslations = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM terjemah'),
    );
    final installedTransliterations = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM transliterasi'),
    );
    final installedSurahs = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM surah'),
    );
    final voiceConfiguration =
        jsonDecode(await rootBundle.loadString('assets/config/suara.json'))
            as Map<String, dynamic>;
    final configuredVoiceIds = (voiceConfiguration['suara'] as List<dynamic>)
        .map((entry) => entry as Map<String, dynamic>)
        .where(
          (voice) =>
              voice['status'] == 'aktif' && voice['audio_mode'] == 'ayah',
        )
        .map((voice) => voice['id'] as String)
        .toList(growable: false);
    var manifestsComplete = configuredVoiceIds.isNotEmpty;
    for (final voiceId in configuredVoiceIds) {
      final audioCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM audio WHERE suara_id = ?', [
          voiceId,
        ]),
      );
      final packageCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM audio_package WHERE suara_id = ?',
          [voiceId],
        ),
      );
      if ((audioCount ?? 0) < 6236 || (packageCount ?? 0) != 30) {
        manifestsComplete = false;
        break;
      }
    }
    if ((installedSurahs ?? 0) >= 114 &&
        (installedAyahs ?? 0) >= 6236 &&
        (installedTranslations ?? 0) >= 6236 &&
        (installedTransliterations ?? 0) >= 6236 &&
        manifestsComplete) {
      return;
    }

    final bundledDatabase = await rootBundle.load(
      'assets/data/tilawahku_content.db',
    );
    final seedPath = '$databasePath.seed';
    final seedFile = File(seedPath);
    await seedFile.writeAsBytes(
      bundledDatabase.buffer.asUint8List(
        bundledDatabase.offsetInBytes,
        bundledDatabase.lengthInBytes,
      ),
      flush: true,
    );
    await db.execute('ATTACH DATABASE ? AS bundled_content', [seedPath]);
    try {
      await db.transaction((transaction) async {
        await transaction.execute(
          'INSERT OR IGNORE INTO surah SELECT * FROM bundled_content.surah',
        );
        await transaction.execute(
          'INSERT OR IGNORE INTO ayah SELECT * FROM bundled_content.ayah',
        );
        await transaction.execute(
          'INSERT OR IGNORE INTO terjemah '
          'SELECT * FROM bundled_content.terjemah',
        );
        await transaction.execute(
          'INSERT OR IGNORE INTO transliterasi '
          'SELECT * FROM bundled_content.transliterasi',
        );
        await transaction.execute(
          'INSERT OR IGNORE INTO suara SELECT * FROM bundled_content.suara',
        );
        await transaction.execute(
          'INSERT OR REPLACE INTO audio SELECT * FROM bundled_content.audio',
        );
        await transaction.execute(
          'INSERT OR IGNORE INTO audio_package '
          'SELECT * FROM bundled_content.audio_package',
        );
        await transaction.execute(
          'INSERT OR REPLACE INTO content_metadata '
          'SELECT * FROM bundled_content.content_metadata',
        );
      });
    } finally {
      await db.execute('DETACH DATABASE bundled_content');
      if (await seedFile.exists()) await seedFile.delete();
    }
  }

  Future<void> ensureBundledContent() async {
    final db = await database;
    final databasesPath = await getDatabasesPath();
    await _ensureBundledContent(db, path.join(databasesPath, 'tilawahku.db'));
  }

  Future<void> close() async {
    final database = _database;
    if (database == null) {
      return;
    }

    await database.close();
    _database = null;
  }
}
