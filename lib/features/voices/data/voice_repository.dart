import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import 'voice_catalog.dart';

class VoiceRepository {
  VoiceRepository({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<void> save(Voice voice) async {
    final db = await _appDatabase.database;
    final values = {
      'nama': voice.name,
      'gaya': voice.style,
      'status': voice.status.value,
    };
    final updated = await db.update(
      'suara',
      values,
      where: 'id = ?',
      whereArgs: [voice.id],
    );
    if (updated == 0) {
      await db.insert(
        'suara',
        {'id': voice.id, ...values},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
