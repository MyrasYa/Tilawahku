import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/memorization/data/memorization_repository.dart';
import 'package:tilawahku/features/memorization/domain/memorization_models.dart';
import 'package:tilawahku/features/navigation/presentation/main_navigation_screen.dart';
import 'package:tilawahku/features/reading/data/reading_repository.dart';
import 'package:tilawahku/features/tajwid/data/tajwid_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Lainnya membuka layar Arah kiblat, bukan placeholder', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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

    await tester.tap(find.text('Lainnya').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Arah kiblat'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('more-options-list')),
        matching: find.byType(Scrollable),
      ),
    );

    final qiblaTile = find.ancestor(
      of: find.text('Arah kiblat'),
      matching: find.byType(ListTile),
    );
    expect(qiblaTile, findsOneWidget);
    expect(
      find.descendant(of: qiblaTile, matching: find.text('Belum tersedia')),
      findsNothing,
    );

    await tester.tap(find.text('Arah kiblat'));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(find.text('Arah Kiblat'), findsOneWidget);
    expect(
      find.text('Tentukan lokasi untuk menghitung kiblat'),
      findsOneWidget,
    );
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
