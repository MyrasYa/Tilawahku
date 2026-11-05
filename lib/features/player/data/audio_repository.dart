import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';

class AudioTrack {
  const AudioTrack({
    required this.globalNumber,
    required this.surahNumber,
    required this.surahName,
    required this.ayahNumber,
    required this.juzNumber,
    required this.relativeFileName,
    required this.filePath,
  });

  final int globalNumber;
  final int surahNumber;
  final String surahName;
  final int ayahNumber;
  final int juzNumber;
  final String relativeFileName;
  final String filePath;

  String get title => '$surahName, ayat $ayahNumber';
}

class AudioRepository {
  AudioRepository({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<List<AudioTrack>> getSurahTracks({
    required int surahNumber,
    required String voiceId,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT audio.nama_file, ayah.nomor_global, ayah.surah, ayah.ayat,
             ayah.juz, surah.nama_id
      FROM audio
      JOIN ayah ON ayah.nomor_global = audio.nomor_global
      JOIN surah ON surah.id = ayah.surah
      WHERE audio.suara_id = ? AND ayah.surah = ?
      ORDER BY ayah.ayat
      ''',
      [voiceId, surahNumber],
    );
    return _toTracks(rows, voiceId);
  }

  Future<List<AudioTrack>> getAllSurahTracks({required String voiceId}) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT audio.nama_file, ayah.nomor_global, ayah.surah, ayah.ayat,
             ayah.juz, surah.nama_id
      FROM audio
      JOIN ayah ON ayah.nomor_global = audio.nomor_global
      JOIN surah ON surah.id = ayah.surah
      WHERE audio.suara_id = ?
      ORDER BY ayah.surah, ayah.ayat
      ''',
      [voiceId],
    );
    return _toTracks(rows, voiceId);
  }

  Future<List<AudioTrack>> getJuzTracks({
    required int juzNumber,
    required String voiceId,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT audio.nama_file, ayah.nomor_global, ayah.surah, ayah.ayat,
             ayah.juz, surah.nama_id
      FROM audio
      JOIN ayah ON ayah.nomor_global = audio.nomor_global
      JOIN surah ON surah.id = ayah.surah
      WHERE audio.suara_id = ? AND ayah.juz = ?
      ORDER BY ayah.nomor_global
      ''',
      [voiceId, juzNumber],
    );
    return _toTracks(rows, voiceId);
  }

  Future<List<AudioTrack>> _toTracks(
    List<Map<String, Object?>> rows,
    String voiceId,
  ) async {
    final appDirectory = await getApplicationSupportDirectory();
    final voiceDirectory = path.join(appDirectory.path, 'audio', voiceId);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(voiceId)) {
      throw FormatException('ID suara tidak valid: $voiceId');
    }

    return rows
        .map((row) {
          final fileName = row['nama_file']! as String;
          final normalizedFileName = path.normalize(fileName);
          if (path.isAbsolute(fileName) ||
              normalizedFileName == '..' ||
              normalizedFileName.startsWith('..${path.separator}')) {
            throw FormatException(
              'Nama file audio harus berupa path relatif aman.',
            );
          }

          final filePath = path.normalize(
            path.join(voiceDirectory, normalizedFileName),
          );
          if (!filePath.startsWith('$voiceDirectory${path.separator}')) {
            throw FormatException('Path audio berada di luar direktori suara.');
          }
          return AudioTrack(
            globalNumber: row['nomor_global']! as int,
            surahNumber: row['surah']! as int,
            surahName: row['nama_id']! as String,
            ayahNumber: row['ayat']! as int,
            juzNumber: row['juz']! as int,
            relativeFileName: normalizedFileName,
            filePath: filePath,
          );
        })
        .toList(growable: false);
  }
}
