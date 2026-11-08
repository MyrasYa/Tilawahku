import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database_schema.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    final database = _database;
    if (database != null) return database;

    final openedDatabase = await databaseFactoryFfiWeb.openDatabase(
      'tilawahku_web_preview.db',
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          for (final statement in DatabaseSchema.createStatements) {
            await db.execute(statement);
          }
          await _seedBundledContent(db);
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
            for (final statement
                in DatabaseSchema.memorizationCreateStatements) {
              await db.execute(statement);
            }
          }
        },
      ),
    );
    _database = openedDatabase;
    return openedDatabase;
  }

  Future<void> _seedBundledContent(Database db) async {
    final fixture =
        jsonDecode(
              await rootBundle.loadString('assets/data/quran_web_preview.json'),
            )
            as Map<String, dynamic>;
    final surahs = fixture['surahs'] as List<dynamic>;
    final ayahs = fixture['ayahs'] as List<dynamic>;

    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final item in surahs) {
        final row = item as List<dynamic>;
        batch.insert('surah', {
          'id': row[0],
          'nama_ar': row[1],
          'nama_id': row[2],
          'jumlah_ayat': row[3],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final item in ayahs) {
        final row = item as List<dynamic>;
        final globalNumber = row[0] as int;
        batch.insert('ayah', {
          'nomor_global': globalNumber,
          'surah': row[1],
          'ayat': row[2],
          'juz': row[3],
          'halaman': row[4],
          'teks_utsmani': row[5],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        batch.insert('terjemah', {
          'nomor_global': globalNumber,
          'teks_id': row[6],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        batch.insert('transliterasi', {
          'nomor_global': globalNumber,
          'teks_latin': row[7],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });

    final voiceConfiguration =
        jsonDecode(await rootBundle.loadString('assets/config/suara.json'))
            as Map<String, dynamic>;
    final voiceBatch = db.batch();
    for (final item in voiceConfiguration['suara'] as List<dynamic>) {
      final voice = item as Map<String, dynamic>;
      voiceBatch.insert('suara', {
        'id': voice['id'],
        'nama': voice['nama'],
        'gaya': voice['gaya'],
        'status': voice['status'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await voiceBatch.commit(noResult: true);
  }

  Future<void> ensureBundledContent() async {
    final db = await database;
    final installedCounts = await Future.wait([
      db.rawQuery('SELECT COUNT(*) FROM surah'),
      db.rawQuery('SELECT COUNT(*) FROM ayah'),
      db.rawQuery('SELECT COUNT(*) FROM terjemah'),
      db.rawQuery('SELECT COUNT(*) FROM transliterasi'),
    ]);
    final counts = installedCounts
        .map(Sqflite.firstIntValue)
        .map((count) => count ?? 0)
        .toList(growable: false);
    if (counts[0] < 114 ||
        counts[1] < 6236 ||
        counts[2] < 6236 ||
        counts[3] < 6236) {
      await _seedBundledContent(db);
    }
  }

  Future<void> close() async {
    final database = _database;
    if (database == null) return;

    await database.close();
    _database = null;
  }
}
