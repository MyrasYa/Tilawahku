import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/app/app_theme.dart';
import 'package:tilawahku/app/tilawahku_app.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/player/data/audio_repository.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';
import 'package:tilawahku/features/reading/presentation/bookmarks_screen.dart';
import 'package:tilawahku/features/reading/presentation/home_screen.dart';
import 'package:tilawahku/features/reading/presentation/reading_screen.dart';
import 'package:tilawahku/features/reading/presentation/search_screen.dart';
import 'package:tilawahku/features/repeat/presentation/repeat_settings_screen.dart';
import 'package:tilawahku/features/voices/data/voice_catalog.dart';
import 'package:tilawahku/features/download/data/surah_audio_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('voice catalog reads the bundled configuration', () async {
    final voices = await const VoiceCatalog().load();

    expect(voices, hasLength(3));
    expect(voices.first.id, 'husary');
    expect(voices[1].id, 'minshawi');
    expect(voices.last.id, 'alafasy');
    expect(voices.last.editionId, 'ar.alafasy');
    expect(voices.every((voice) => voice.status == VoiceStatus.active), isTrue);
  });

  test('ayah entries read the bundled Latin transliteration', () {
    final ayah = AyahEntry.fromMap({
      'nomor_global': 1,
      'surah': 1,
      'ayat': 1,
      'juz': 1,
      'halaman': 1,
      'teks_utsmani': 'بِسْمِ اللَّهِ',
      'teks_latin': 'Bismillaahir Rahmaanir Raheem',
      'teks_id': 'Dengan nama Allah',
    });

    expect(ayah.transliteration, 'Bismillaahir Rahmaanir Raheem');
  });

  test(
    'surah audio package reports completion only when every ayah exists',
    () {
      const package = SurahAudioPackage(
        voiceId: 'husary',
        surahNumber: 1,
        surahName: 'Al-Fatihah',
        totalAyahs: 7,
        downloadedAyahs: 6,
        downloadedBytes: 1200,
      );
      const completePackage = SurahAudioPackage(
        voiceId: 'husary',
        surahNumber: 1,
        surahName: 'Al-Fatihah',
        totalAyahs: 7,
        downloadedAyahs: 7,
        downloadedBytes: 1400,
      );

      expect(package.isComplete, isFalse);
      expect(completePackage.isComplete, isTrue);
    },
  );

  testWidgets('first launch opens onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TilawahkuApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Baca dengan tenang'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
  });

  testWidgets('home opens the reader without a selected voice', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: _FakeReadingRepository(),
          preferences: const _NoVoiceReaderPreferences(),
          onSetDarkMode: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mulai Membaca'), findsOneWidget);
    await tester.tap(find.text('Mulai Membaca'));
    await tester.pumpAndSettle();
    expect(find.text('بِسْمِ اللَّهِ'), findsOneWidget);
  });

  testWidgets('repeat settings exposes ayah repetition count', (tester) async {
    final tracks = [
      const AudioTrack(
        globalNumber: 1,
        surahNumber: 1,
        surahName: 'Al-Fatihah',
        ayahNumber: 1,
        juzNumber: 1,
        relativeFileName: '001001.mp3',
        filePath: '/local/audio/001001.mp3',
      ),
      const AudioTrack(
        globalNumber: 2,
        surahNumber: 1,
        surahName: 'Al-Fatihah',
        ayahNumber: 2,
        juzNumber: 1,
        relativeFileName: '001002.mp3',
        filePath: '/local/audio/001002.mp3',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RepeatSettingsScreen(tracks: tracks, currentGlobalAyah: 1),
      ),
    );

    await tester.tap(find.text('Ulang ayat aktif'));
    await tester.pumpAndSettle();
    expect(find.text('Jumlah putaran: 3'), findsOneWidget);
    expect(find.text('Ulang rentang ayat'), findsOneWidget);
  });

  testWidgets('search offers only the three requested filters', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          repository: ReadingRepository(),
          preferences: const AppPreferences(),
        ),
      ),
    );

    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Surah'), findsOneWidget);
    expect(find.text('Terjemahan'), findsOneWidget);
    expect(find.text('Arab'), findsNothing);
    expect(
      find.text('Semua: cari nama surah, teks Arab, atau terjemahan.'),
      findsOneWidget,
    );
  });

  testWidgets('reading page navigation opens the selected page', (
    tester,
  ) async {
    final repository = _FakeReadingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ReadingScreen(
          repository: repository,
          preferences: const _ReaderPreferences(),
          pageNumber: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Halaman 1'), findsOneWidget);
    expect(repository.savedProgress, contains(('husary', 1)));
    await tester.tap(find.byTooltip('Buka halaman'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '604');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Halaman 604'), findsOneWidget);
    expect(find.text('Ayat halaman 604'), findsOneWidget);
    expect(repository.savedProgress, contains(('husary', 604)));
    await tester.tap(find.byTooltip('Simpan bookmark'));
    await tester.pumpAndSettle();
    expect(
      repository.bookmarks.map((ayah) => ayah.globalNumber),
      contains(604),
    );
  });

  testWidgets('reader remains available without selecting a voice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingScreen(
          repository: _FakeReadingRepository(),
          preferences: const _NoVoiceReaderPreferences(),
          surahNumber: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بِسْمِ اللَّهِ'), findsOneWidget);
    expect(find.text('Dengan nama Allah'), findsOneWidget);
    expect(find.byTooltip('Simpan bookmark'), findsOneWidget);
  });

  testWidgets('reading progress follows the visible ayah while scrolling', (
    tester,
  ) async {
    final repository = _FakeReadingRepository()
      ..surahAyahs = List.generate(
        20,
        (index) => AyahEntry(
          globalNumber: index + 1,
          surahNumber: 1,
          ayahNumber: index + 1,
          juzNumber: 1,
          pageNumber: 1,
          uthmaniText: 'بِسْمِ اللَّهِ',
          indonesianTranslation: 'Ayat ${index + 1}',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: ReadingScreen(
          repository: repository,
          preferences: const _ReaderPreferences(),
          surahNumber: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.savedProgress.any((entry) => entry.$2 > 1), isTrue);
  });

  testWidgets('bookmarks can be opened from their list and removed', (
    tester,
  ) async {
    final repository = _FakeReadingRepository()..bookmarks = [_sampleAyah()];

    await tester.pumpWidget(
      MaterialApp(
        home: BookmarksScreen(
          repository: repository,
          preferences: const AppPreferences(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Al-Fatihah · 1:1'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus bookmark'));
    await tester.pumpAndSettle();

    expect(repository.bookmarks, isEmpty);
    expect(find.text('Al-Fatihah · 1:1'), findsNothing);
  });

  test('dark theme styles dialogs and download progress', () {
    expect(AppColors.navy, const Color(0xFF132A4C));
    expect(AppColors.gold, const Color(0xFFE6B325));
    expect(AppColors.parchment, const Color(0xFFEDEAE0));
    expect(AppColors.blue, const Color(0xFF2C4870));
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.parchment);
    expect(AppTheme.light.colorScheme.primary, AppColors.navy);
    expect(AppTheme.light.colorScheme.secondary, AppColors.gold);
    expect(AppTheme.light.colorScheme.tertiary, AppColors.blue);
    expect(AppTheme.dark.dialogTheme.backgroundColor, isNotNull);
    expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.navy);
    expect(AppTheme.dark.colorScheme.primary, AppColors.gold);
    expect(AppTheme.dark.colorScheme.secondary, AppColors.blue);
    expect(AppTheme.dark.progressIndicatorTheme.color, AppColors.gold);
    expect(AppTheme.dark.progressIndicatorTheme.linearTrackColor, isNotNull);
  });
}

class _FakeReadingRepository extends ReadingRepository {
  List<AyahEntry> bookmarks = [];
  List<AyahEntry>? surahAyahs;
  final List<(String, int)> savedProgress = [];

  @override
  Future<List<Surah>> getSurahs() async => const [
    Surah(
      id: 1,
      nameArabic: 'الفاتحة',
      nameIndonesian: 'Al-Fatihah',
      ayahCount: 7,
    ),
  ];

  @override
  Future<AyahEntry?> getProgress(String voiceId) async => null;

  @override
  Future<List<AyahEntry>> getAyahsForSurah(
    int surahNumber, {
    int? limit,
  }) async => surahAyahs ?? [_sampleAyah()];

  @override
  Future<int> getPageCount() async => 604;

  @override
  Future<List<AyahEntry>> getAyahsForPage(int pageNumber) async => [
    AyahEntry(
      globalNumber: pageNumber,
      surahNumber: 1,
      ayahNumber: 1,
      juzNumber: 1,
      pageNumber: pageNumber,
      uthmaniText: 'بِسْمِ اللَّهِ',
      indonesianTranslation: 'Ayat halaman $pageNumber',
    ),
  ];

  @override
  Future<Set<int>> getBookmarkedNumbers(List<int> globalAyahNumbers) async =>
      bookmarks.map((ayah) => ayah.globalNumber).toSet();

  @override
  Future<List<AyahEntry>> getBookmarks() async => bookmarks;

  @override
  Future<void> saveProgress({
    required String voiceId,
    required int globalAyahNumber,
  }) async {
    savedProgress.add((voiceId, globalAyahNumber));
  }

  @override
  Future<void> setBookmarked(int globalAyahNumber, bool bookmarked) async {
    if (bookmarked) {
      if (!bookmarks.any((ayah) => ayah.globalNumber == globalAyahNumber)) {
        bookmarks = [...bookmarks, _sampleAyah(globalAyahNumber)];
      }
    } else {
      bookmarks = bookmarks
          .where((ayah) => ayah.globalNumber != globalAyahNumber)
          .toList();
    }
  }
}

class _ReaderPreferences extends AppPreferences {
  const _ReaderPreferences();

  @override
  Future<String?> get selectedVoiceId async => 'husary';

  @override
  Future<bool> get translationVisible async => true;

  @override
  Future<double> get arabicTextScale async => 1;
}

class _NoVoiceReaderPreferences extends AppPreferences {
  const _NoVoiceReaderPreferences();

  @override
  Future<String?> get selectedVoiceId async => null;

  @override
  Future<bool> get translationVisible async => true;

  @override
  Future<double> get arabicTextScale async => 1;
}

AyahEntry _sampleAyah([int globalNumber = 1]) => AyahEntry(
  globalNumber: globalNumber,
  surahNumber: 1,
  ayahNumber: 1,
  juzNumber: 1,
  pageNumber: 1,
  uthmaniText: 'بِسْمِ اللَّهِ',
  indonesianTranslation: 'Dengan nama Allah',
  surahNameIndonesian: 'Al-Fatihah',
);
