import '../../../core/database/app_database.dart';

enum AudioPackageStatus {
  notDownloaded('not_downloaded'),
  queued('queued'),
  downloading('downloading'),
  paused('paused'),
  failed('failed'),
  complete('complete');

  const AudioPackageStatus(this.value);

  final String value;

  static AudioPackageStatus parse(String value) =>
      AudioPackageStatus.values.firstWhere((status) => status.value == value);
}

class AudioPackage {
  const AudioPackage({
    required this.voiceId,
    required this.juz,
    required this.status,
    required this.totalAyah,
    required this.downloadedAyah,
    required this.totalBytes,
    required this.downloadedBytes,
    this.error,
  });

  final String voiceId;
  final int juz;
  final AudioPackageStatus status;
  final int totalAyah;
  final int downloadedAyah;
  final int totalBytes;
  final int downloadedBytes;
  final String? error;

  double get progress => totalAyah == 0 ? 0 : downloadedAyah / totalAyah;

  int get remainingBytes => (totalBytes - downloadedBytes).clamp(0, totalBytes);

  factory AudioPackage.fromMap(Map<String, Object?> row) => AudioPackage(
    voiceId: row['suara_id']! as String,
    juz: row['juz']! as int,
    status: AudioPackageStatus.parse(row['status']! as String),
    totalAyah: row['total_ayah']! as int,
    downloadedAyah: row['downloaded_ayah']! as int,
    totalBytes: row['total_bytes']! as int,
    downloadedBytes: row['downloaded_bytes']! as int,
    error: row['error'] as String?,
  );
}

class AudioPackageRepository {
  AudioPackageRepository({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<List<AudioPackage>> getPackages(String voiceId) async {
    await _appDatabase.ensureBundledContent();
    final db = await _appDatabase.database;
    final rows = await db.query(
      'audio_package',
      where: 'suara_id = ?',
      whereArgs: [voiceId],
      orderBy: 'juz',
    );
    final packages = rows.map(AudioPackage.fromMap).toList(growable: false);
    if (packages.length != 30) {
      throw StateError(
        'Manifest audio untuk suara "$voiceId" tidak lengkap '
        '(${packages.length}/30 juz).',
      );
    }
    return packages;
  }

  Future<AudioPackage> getPackage({
    required String voiceId,
    required int juz,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'audio_package',
      where: 'suara_id = ? AND juz = ?',
      whereArgs: [voiceId, juz],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Paket audio $voiceId / juz $juz tidak ditemukan.');
    }
    return AudioPackage.fromMap(rows.single);
  }

  Future<void> recoverInterruptedDownloads(String voiceId) async {
    final db = await _appDatabase.database;
    await db.update(
      'audio_package',
      {
        'status': AudioPackageStatus.paused.value,
        'error': 'Unduhan dijeda saat aplikasi ditutup.',
        'diperbarui_pada': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'suara_id = ? AND status IN (?, ?)',
      whereArgs: [
        voiceId,
        AudioPackageStatus.downloading.value,
        AudioPackageStatus.queued.value,
      ],
    );
  }

  Future<void> update({
    required String voiceId,
    required int juz,
    required AudioPackageStatus status,
    required int downloadedAyah,
    required int downloadedBytes,
    int? totalBytes,
    String? error,
  }) async {
    final db = await _appDatabase.database;
    final changes = await db.update(
      'audio_package',
      {
        'status': status.value,
        'downloaded_ayah': downloadedAyah,
        'downloaded_bytes': downloadedBytes,
        'total_bytes': ?totalBytes,
        'error': error,
        'diperbarui_pada': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'suara_id = ? AND juz = ?',
      whereArgs: [voiceId, juz],
    );
    if (changes != 1) {
      throw StateError('Paket audio $voiceId / juz $juz tidak ditemukan.');
    }
  }

  Future<void> reset({required String voiceId, required int juz}) async {
    final db = await _appDatabase.database;
    final changes = await db.update(
      'audio_package',
      {
        'status': AudioPackageStatus.notDownloaded.value,
        'downloaded_ayah': 0,
        'downloaded_bytes': 0,
        'total_bytes': 0,
        'error': null,
        'diperbarui_pada': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'suara_id = ? AND juz = ?',
      whereArgs: [voiceId, juz],
    );
    if (changes != 1) {
      throw StateError('Paket audio $voiceId / juz $juz tidak ditemukan.');
    }
  }
}
