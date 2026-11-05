abstract final class DatabaseSchema {
  static const version = 4;

  static const createSurah = '''
    CREATE TABLE surah (
      id INTEGER PRIMARY KEY,
      nama_ar TEXT NOT NULL,
      nama_id TEXT NOT NULL,
      jumlah_ayat INTEGER NOT NULL CHECK (jumlah_ayat > 0)
    )
  ''';

  static const createAyah = '''
    CREATE TABLE ayah (
      nomor_global INTEGER PRIMARY KEY,
      surah INTEGER NOT NULL,
      ayat INTEGER NOT NULL,
      juz INTEGER NOT NULL,
      halaman INTEGER NOT NULL,
      teks_utsmani TEXT NOT NULL,
      FOREIGN KEY (surah) REFERENCES surah (id),
      UNIQUE (surah, ayat)
    )
  ''';

  static const createTerjemah = '''
    CREATE TABLE terjemah (
      nomor_global INTEGER PRIMARY KEY,
      teks_id TEXT NOT NULL,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
        ON DELETE CASCADE
    )
  ''';

  static const createTransliterasi = '''
    CREATE TABLE transliterasi (
      nomor_global INTEGER PRIMARY KEY,
      teks_latin TEXT NOT NULL,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
        ON DELETE CASCADE
    )
  ''';

  static const createSuara = '''
    CREATE TABLE suara (
      id TEXT PRIMARY KEY,
      nama TEXT NOT NULL,
      gaya TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('aktif', 'segera_hadir', 'nonaktif'))
    )
  ''';

  static const createAudio = '''
    CREATE TABLE audio (
      nomor_global INTEGER NOT NULL,
      suara_id TEXT NOT NULL,
      nama_file TEXT NOT NULL,
      PRIMARY KEY (nomor_global, suara_id),
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
        ON DELETE CASCADE,
      FOREIGN KEY (suara_id) REFERENCES suara (id)
        ON DELETE CASCADE
    )
  ''';

  static const createBookmark = '''
    CREATE TABLE bookmark (
      nomor_global INTEGER PRIMARY KEY,
      dibuat_pada TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
        ON DELETE CASCADE
    )
  ''';

  static const createProgres = '''
    CREATE TABLE progres (
      suara_id TEXT PRIMARY KEY,
      nomor_global INTEGER NOT NULL,
      diperbarui_pada TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (suara_id) REFERENCES suara (id),
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
    )
  ''';

  static const createAudioPackage = '''
    CREATE TABLE audio_package (
      suara_id TEXT NOT NULL,
      juz INTEGER NOT NULL CHECK (juz BETWEEN 1 AND 30),
      status TEXT NOT NULL DEFAULT 'not_downloaded'
        CHECK (status IN (
          'not_downloaded', 'queued', 'downloading', 'paused',
          'failed', 'complete'
        )),
      total_ayah INTEGER NOT NULL CHECK (total_ayah > 0),
      downloaded_ayah INTEGER NOT NULL DEFAULT 0,
      total_bytes INTEGER NOT NULL DEFAULT 0,
      downloaded_bytes INTEGER NOT NULL DEFAULT 0,
      error TEXT,
      diperbarui_pada TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (suara_id, juz),
      FOREIGN KEY (suara_id) REFERENCES suara (id) ON DELETE CASCADE
    )
  ''';

  static const createContentMetadata = '''
    CREATE TABLE content_metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const createAyahSurahIndex =
      'CREATE INDEX ayah_surah_ayat_idx ON ayah (surah, ayat)';
  static const createAyahJuzIndex =
      'CREATE INDEX ayah_juz_nomor_idx ON ayah (juz, nomor_global)';
  static const createAyahHalamanIndex =
      'CREATE INDEX ayah_halaman_nomor_idx ON ayah (halaman, nomor_global)';

  static const createStatements = [
    createSurah,
    createAyah,
    createTerjemah,
    createTransliterasi,
    createSuara,
    createAudio,
    createBookmark,
    createProgres,
    createAudioPackage,
    createContentMetadata,
    createAyahSurahIndex,
    createAyahJuzIndex,
    createAyahHalamanIndex,
  ];
}
