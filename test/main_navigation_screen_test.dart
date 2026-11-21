import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/memorization/data/memorization_repository.dart';
import 'package:tilawahku/features/memorization/domain/memorization_models.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';
import 'package:tilawahku/features/tajwid/data/tajwid_repository.dart';
import 'package:tilawahku/features/navigation/presentation/main_navigation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main navigation switches between the four primary sections', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final readingRepository = _FakeReadingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationScreen(
          preferences: const AppPreferences(),
          onSetDarkMode: (_) {},
          readingRepository: readingRepository,
          memorizationRepository: MemorizationRepository(
            store: _EmptyMemorizationStore(),
            readingRepository: readingRepository,
          ),
          tajwidRepository: TajwidRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akses cepat'), findsOneWidget);
    await tester.tap(find.text('Al-Qur’an').last);
    await tester.pumpAndSettle();
    expect(find.text('Juz'), findsOneWidget);
    expect(find.text('Surah'), findsOneWidget);

    await tester.tap(find.text('Aktivitas').last);
    await tester.pumpAndSettle();
    expect(find.text('Riwayat hafalan'), findsOneWidget);
    expect(find.text('Belum tersedia'), findsWidgets);

    await tester.tap(find.text('Lainnya').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pengaturan'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('more-options-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Pengaturan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tentang aplikasi'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('more-options-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Tentang aplikasi'), findsOneWidget);

    await tester.tap(find.text('Beranda').last);
    await tester.pumpAndSettle();
    expect(find.text('Akses cepat'), findsOneWidget);
  });
}

class _FakeReadingRepository extends ReadingRepository {
  @override
  Future<List<Surah>> getSurahs() async => const [];

  @override
  Future<AyahEntry?> getProgress(String voiceId) async => null;
}

class _EmptyMemorizationStore implements MemorizationStore {
  @override
  Future<List<MemorizationProgram>> getPrograms() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
