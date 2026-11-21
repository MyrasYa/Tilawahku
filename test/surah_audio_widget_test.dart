import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';
import 'package:tilawahku/features/reading/presentation/reading_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('surah-based qari uses full-surah player controls only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingScreen(
          repository: _ReadingRepository(),
          preferences: const _LuhaidanPreferences(),
          surahNumber: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Muhammad Al-Luhaidan'), findsOneWidget);
    expect(find.text('Mode Audio Per Surah'), findsOneWidget);
    expect(
      find.textContaining('Pengulangan ayat atau rentang ayat belum tersedia'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
    expect(find.byTooltip('Putar surah utuh'), findsOneWidget);
  });
}

class _LuhaidanPreferences extends AppPreferences {
  const _LuhaidanPreferences();

  @override
  Future<String?> get selectedVoiceId async => 'muhammad-al-luhaidan';

  @override
  Future<bool> get translationVisible async => true;

  @override
  Future<double> get arabicTextScale async => 1;
}

class _ReadingRepository extends ReadingRepository {
  @override
  Future<AyahEntry?> getProgress(String voiceId) async => null;

  @override
  Future<List<AyahEntry>> getAyahsForSurah(
    int surahNumber, {
    int? limit,
  }) async => [
    AyahEntry(
      globalNumber: 1,
      surahNumber: 1,
      ayahNumber: 1,
      juzNumber: 1,
      pageNumber: 1,
      uthmaniText: 'بِسْمِ اللَّهِ',
      indonesianTranslation: 'Dengan nama Allah',
    ),
  ];

  @override
  Future<Set<int>> getBookmarkedNumbers(List<int> globalAyahNumbers) async =>
      <int>{};
}
