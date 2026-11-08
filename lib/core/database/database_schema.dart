abstract final class DatabaseSchema {
  static const version = 5;

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

  static const createMemorizationProgram = '''
    CREATE TABLE memorization_program (
      id TEXT PRIMARY KEY,
      nama TEXT NOT NULL,
      scope TEXT NOT NULL CHECK (scope IN ('surah', 'juz', 'range')),
      start_global INTEGER NOT NULL,
      end_global INTEGER NOT NULL,
      daily_target INTEGER NOT NULL CHECK (daily_target > 0),
      dibuat_pada TEXT NOT NULL,
      diperbarui_pada TEXT NOT NULL,
      CHECK (start_global <= end_global),
      FOREIGN KEY (start_global) REFERENCES ayah (nomor_global),
      FOREIGN KEY (end_global) REFERENCES ayah (nomor_global)
    )
  ''';

  static const createMemorizationAyahProgress = '''
    CREATE TABLE memorization_ayah_progress (
      program_id TEXT NOT NULL,
      nomor_global INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'learning'
        CHECK (status IN (
          'not_started', 'learning', 'in_progress', 'needs_review', 'mastered'
        )),
      first_learned_on TEXT,
      last_practiced_at TEXT NOT NULL,
      diperbarui_pada TEXT NOT NULL,
      PRIMARY KEY (program_id, nomor_global),
      FOREIGN KEY (program_id) REFERENCES memorization_program (id)
        ON DELETE CASCADE,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
    )
  ''';

  static const createMemorizationSession = '''
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
  ''';

  static const createMemorizationSessionAyah = '''
    CREATE TABLE memorization_session_ayah (
      session_id TEXT NOT NULL,
      nomor_global INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 1,
      newly_learned INTEGER NOT NULL DEFAULT 0
        CHECK (newly_learned IN (0, 1)),
      first_practiced_at TEXT NOT NULL,
      last_practiced_at TEXT NOT NULL,
      result TEXT,
      PRIMARY KEY (session_id, nomor_global),
      FOREIGN KEY (session_id) REFERENCES memorization_session (id)
        ON DELETE CASCADE,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
    )
  ''';

  static const createMemorizationStatusHistory = '''
    CREATE TABLE memorization_status_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      program_id TEXT NOT NULL,
      nomor_global INTEGER NOT NULL,
      session_id TEXT,
      old_status TEXT,
      new_status TEXT NOT NULL
        CHECK (new_status IN (
          'not_started', 'learning', 'in_progress', 'needs_review', 'mastered'
        )),
      changed_at TEXT NOT NULL,
      FOREIGN KEY (program_id) REFERENCES memorization_program (id)
        ON DELETE CASCADE,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global),
      FOREIGN KEY (session_id) REFERENCES memorization_session (id)
        ON DELETE SET NULL
    )
  ''';

  static const createMemorizationProgressIndex =
      'CREATE INDEX memorization_progress_day_idx '
      'ON memorization_ayah_progress (program_id, first_learned_on)';
  static const createMemorizationSessionsIndex =
      'CREATE INDEX memorization_sessions_program_idx '
      'ON memorization_session (program_id, started_at DESC)';
  static const createMemorizationHistoryIndex =
      'CREATE INDEX memorization_history_program_idx '
      'ON memorization_status_history (program_id, changed_at DESC)';

  static const memorizationCreateStatements = [
    createMemorizationProgram,
    createMemorizationAyahProgress,
    createMemorizationSession,
    createMemorizationSessionAyah,
    createMemorizationStatusHistory,
    createMemorizationProgressIndex,
    createMemorizationSessionsIndex,
    createMemorizationHistoryIndex,
  ];

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
    ...memorizationCreateStatements,
  ];
}
