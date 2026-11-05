import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/app/app_theme.dart';
import 'package:tilawahku/app/tilawahku_app.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/player/data/audio_repository.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';
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
