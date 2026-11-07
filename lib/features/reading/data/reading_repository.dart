import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class Surah {
  const Surah({
    required this.id,
    required this.nameArabic,
    required this.nameIndonesian,
    required this.ayahCount,
  });

  final int id;
  final String nameArabic;
  final String nameIndonesian;
  final int ayahCount;

  factory Surah.fromMap(Map<String, Object?> map) => Surah(
    id: map['id']! as int,
    nameArabic: map['nama_ar']! as String,
    nameIndonesian: map['nama_id']! as String,
    ayahCount: map['jumlah_ayat']! as int,
  );
}

class AyahEntry {
  const AyahEntry({
    required this.globalNumber,
    required this.surahNumber,
    required this.ayahNumber,
    required this.juzNumber,
    required this.pageNumber,
    required this.uthmaniText,
    this.transliteration,
    this.indonesianTranslation,
    this.surahNameIndonesian,
  });

  final int globalNumber;
  final int surahNumber;
  final int ayahNumber;
  final int juzNumber;
  final int pageNumber;
  final String uthmaniText;
  final String? transliteration;
  final String? indonesianTranslation;
  final String? surahNameIndonesian;

  factory AyahEntry.fromMap(Map<String, Object?> map) => AyahEntry(
    globalNumber: map['nomor_global']! as int,
    surahNumber: map['surah']! as int,
    ayahNumber: map['ayat']! as int,
    juzNumber: map['juz']! as int,
    pageNumber: map['halaman']! as int,
    uthmaniText: map['teks_utsmani']! as String,
    transliteration: map['teks_latin'] as String?,
    indonesianTranslation: map['teks_id'] as String?,
    surahNameIndonesian: map['nama_surah_id'] as String?,
  );
}

class QuranSearchResult {
  const QuranSearchResult({required this.ayah, required this.surah});

  final AyahEntry ayah;
  final Surah surah;
}

enum QuranSearchFilter { all, translation, arabic, surah }

class ReadingRepository {
  ReadingRepository({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance;

  final AppDatabase _appDatabase;
  Future<List<QuranSearchResult>>? _searchIndex;

  Future<List<QuranSearchResult>> search(
    String query, {
    QuranSearchFilter filter = QuranSearchFilter.all,
  }) async {
    final normalizedQuery = _normalizeText(query);
    if (normalizedQuery.isEmpty) return const [];

    final index = await (_searchIndex ??= _loadSearchIndex());
    final reference = _parseReference(query);
    if (reference != null) {
      return index
          .where(
            (result) =>
                result.ayah.surahNumber == reference.$1 &&
                result.ayah.ayahNumber == reference.$2,
          )
          .take(1)
          .toList(growable: false);
    }

    final namedAyahReference = _parseNamedAyahReference(query);
    if (namedAyahReference != null) {
      final nameQuery = _normalizeText(namedAyahReference.$1);
      final namedReferenceResults = index
          .where(
            (result) =>
                result.ayah.ayahNumber == namedAyahReference.$2 &&
                _matchesSurah(result.surah, nameQuery),
          )
          .take(20)
          .toList(growable: false);
      if (namedReferenceResults.isNotEmpty) return namedReferenceResults;
    }

    final arabicQuery = _normalizeArabic(query);
    final matches = <QuranSearchResult>[];
    final matchedSurahs = <int>{};
    for (final result in index) {
      final translationMatches = _normalizeText(
        result.ayah.indonesianTranslation ?? '',
      ).contains(normalizedQuery);
      final arabicMatches =
          arabicQuery.isNotEmpty &&
          _normalizeArabic(result.ayah.uthmaniText).contains(arabicQuery);
      final surahMatches = _matchesSurah(result.surah, normalizedQuery);

      final matchesFilter = switch (filter) {
        QuranSearchFilter.all =>
          translationMatches || arabicMatches || surahMatches,
        QuranSearchFilter.translation => translationMatches,
        QuranSearchFilter.arabic => arabicMatches,
        QuranSearchFilter.surah => surahMatches,
      };
      if (!matchesFilter) continue;

      if (filter == QuranSearchFilter.surah ||
          (surahMatches && !translationMatches && !arabicMatches)) {
        if (matchedSurahs.add(result.surah.id) && result.ayah.ayahNumber == 1) {
          matches.add(result);
        }
      } else {
        matches.add(result);
      }
      if (matches.length >= 100) break;
    }
    return matches;
  }

  Future<List<QuranSearchResult>> _loadSearchIndex() async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT ayah.*, transliterasi.teks_latin, terjemah.teks_id,
        surah.id AS search_surah_id,
        surah.nama_ar AS search_nama_ar,
        surah.nama_id AS search_nama_id,
        surah.jumlah_ayat AS search_jumlah_ayat
      FROM ayah
      JOIN surah ON surah.id = ayah.surah
      LEFT JOIN terjemah USING (nomor_global)
      LEFT JOIN transliterasi USING (nomor_global)
      ORDER BY ayah.nomor_global
    ''');
    return rows
        .map(
          (row) => QuranSearchResult(
            ayah: AyahEntry.fromMap(row),
            surah: Surah(
              id: row['search_surah_id']! as int,
              nameArabic: row['search_nama_ar']! as String,
              nameIndonesian: row['search_nama_id']! as String,
              ayahCount: row['search_jumlah_ayat']! as int,
            ),
          ),
        )
        .toList(growable: false);
  }

  static (int, int)? _parseReference(String value) {
    final match = RegExp(
      r'^\s*(\d{1,3})\s*[:/]\s*(\d{1,3})\s*$',
    ).firstMatch(value);
    if (match == null) return null;
    final surah = int.parse(match.group(1)!);
    final ayah = int.parse(match.group(2)!);
    if (surah < 1 || surah > 114 || ayah < 1) return null;
    return (surah, ayah);
  }

  static (String, int)? _parseNamedAyahReference(String value) {
    final match = RegExp(r'^\s*(.+?)\s+(\d{1,3})\s*$').firstMatch(value);
    if (match == null) return null;
    final name = match.group(1)!.trim();
    final ayah = int.parse(match.group(2)!);
    if (name.isEmpty || ayah < 1) return null;
    return (name, ayah);
  }

  static bool _matchesSurah(Surah surah, String normalizedQuery) =>
      _normalizeText(surah.nameIndonesian).contains(normalizedQuery) ||
      _normalizeArabic(
        surah.nameArabic,
      ).contains(_normalizeArabic(normalizedQuery));

  static String _normalizeText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[-_.,!?;:()]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _normalizeArabic(String value) {
    final normalized = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      if (rune == 0x0640 ||
          (rune >= 0x064B && rune <= 0x065F) ||
          rune == 0x0670 ||
          (rune >= 0x06D6 && rune <= 0x06ED)) {
        continue;
      }
      normalized.writeCharCode(switch (rune) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627,
        0x0649 => 0x064A,
        _ => rune,
      });
    }
    return normalized.toString();
  }

  Future<List<Surah>> getSurahs() async {
    final db = await _appDatabase.database;
    final rows = await db.query('surah', orderBy: 'id');
    return rows.map(Surah.fromMap).toList(growable: false);
  }

  Future<List<AyahEntry>> getAyahsForSurah(
    int surahNumber, {
    int? limit,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT ayah.*, transliterasi.teks_latin, terjemah.teks_id
      FROM ayah
      LEFT JOIN terjemah USING (nomor_global)
      LEFT JOIN transliterasi USING (nomor_global)
      WHERE surah = ?
      ORDER BY ayat
      ${limit == null ? '' : 'LIMIT ?'}
      ''',
      [surahNumber, ?limit],
    );
    return rows.map(AyahEntry.fromMap).toList(growable: false);
  }

  Future<List<AyahEntry>> getAyahsForJuz(int juzNumber) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT ayah.*, transliterasi.teks_latin, terjemah.teks_id
      FROM ayah
      LEFT JOIN terjemah USING (nomor_global)
      LEFT JOIN transliterasi USING (nomor_global)
      WHERE juz = ?
      ORDER BY nomor_global
      ''',
      [juzNumber],
    );
    return rows.map(AyahEntry.fromMap).toList(growable: false);
  }

  Future<List<AyahEntry>> getAyahsForPage(int pageNumber) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT ayah.*, transliterasi.teks_latin, terjemah.teks_id
      FROM ayah
      LEFT JOIN terjemah USING (nomor_global)
      LEFT JOIN transliterasi USING (nomor_global)
      WHERE halaman = ?
      ORDER BY nomor_global
      ''',
      [pageNumber],
    );
    return rows.map(AyahEntry.fromMap).toList(growable: false);
  }

  Future<int> getPageCount() async {
    final db = await _appDatabase.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT MAX(halaman) FROM ayah'),
        ) ??
        0;
  }

  Future<void> setBookmarked(int globalAyahNumber, bool bookmarked) async {
    final db = await _appDatabase.database;
    if (bookmarked) {
      await db.insert('bookmark', {
        'nomor_global': globalAyahNumber,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'bookmark',
        where: 'nomor_global = ?',
        whereArgs: [globalAyahNumber],
      );
    }
  }

  Future<bool> isBookmarked(int globalAyahNumber) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'bookmark',
      columns: ['nomor_global'],
      where: 'nomor_global = ?',
      whereArgs: [globalAyahNumber],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<int>> getBookmarkedNumbers(List<int> globalAyahNumbers) async {
    if (globalAyahNumbers.isEmpty) return {};

    final db = await _appDatabase.database;
    final placeholders = List.filled(globalAyahNumbers.length, '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT nomor_global FROM bookmark '
      'WHERE nomor_global IN ($placeholders)',
      globalAyahNumbers,
    );
    return rows.map((row) => row['nomor_global']! as int).toSet();
  }

  Future<List<AyahEntry>> getBookmarks() async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT ayah.*, transliterasi.teks_latin, terjemah.teks_id,
             surah.nama_id AS nama_surah_id
      FROM bookmark
      JOIN ayah USING (nomor_global)
      LEFT JOIN terjemah USING (nomor_global)
      LEFT JOIN transliterasi USING (nomor_global)
      JOIN surah ON surah.id = ayah.surah
      ORDER BY bookmark.dibuat_pada DESC
    ''');
    return rows.map(AyahEntry.fromMap).toList(growable: false);
  }

  Future<void> saveProgress({
    required String voiceId,
    required int globalAyahNumber,
  }) async {
    final db = await _appDatabase.database;
    await db.insert('progres', {
      'suara_id': voiceId,
      'nomor_global': globalAyahNumber,
      'diperbarui_pada': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AyahEntry?> getProgress(String voiceId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT ayah.*, transliterasi.teks_latin, terjemah.teks_id,
             surah.nama_id AS nama_surah_id
      FROM progres
      JOIN ayah USING (nomor_global)
      LEFT JOIN terjemah USING (nomor_global)
      LEFT JOIN transliterasi USING (nomor_global)
      JOIN surah ON surah.id = ayah.surah
      WHERE progres.suara_id = ?
      LIMIT 1
      ''',
      [voiceId],
    );
    return rows.isEmpty ? null : AyahEntry.fromMap(rows.single);
  }
}
