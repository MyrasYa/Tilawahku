import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';
import 'package:tilawahku/features/tajwid/domain/tajwid_catalog.dart';
import 'package:tilawahku/features/tajwid/presentation/tajwid_lesson_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lesson opens its local example in Reader and returns', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final lesson = TajwidCatalog.lessons.firstWhere(
      (item) => item.id == 'idgham-bighunnah',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TajwidLessonScreen(
          lesson: lesson,
          readingRepository: _FakeReadingRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final readerButton = find.byKey(const ValueKey('tajwid-open-reader'));
    await tester.scrollUntilVisible(
      readerButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(readerButton);
    await tester.pumpAndSettle();

    expect(find.text('Surah 2'), findsOneWidget);
    expect(find.text('Ayat contoh'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Idgham Bighunnah'), findsOneWidget);
    expect(find.byKey(const ValueKey('tajwid-open-reader')), findsOneWidget);
  });
}

class _FakeReadingRepository extends ReadingRepository {
  @override
  Future<List<AyahEntry>> getAyahsForSurah(
    int surahNumber, {
    int? limit,
  }) async => [
    AyahEntry(
      globalNumber: 5,
      surahNumber: 2,
      ayahNumber: 5,
      juzNumber: 1,
      pageNumber: 2,
      uthmaniText: 'Ayat contoh',
      indonesianTranslation: 'Terjemahan ayat',
      surahNameIndonesian: 'Al-Baqarah',
    ),
  ];

  @override
  Future<Set<int>> getBookmarkedNumbers(List<int> globalAyahNumbers) async =>
      {};
}
