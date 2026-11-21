import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/download/presentation/download_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('surah-based qari is not offered ayah-based offline downloads', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DownloadScreen(preferences: const _LuhaidanPreferences()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Unduhan offline belum tersedia untuk sumber ini.'),
      findsOneWidget,
    );
    expect(find.text('Juz'), findsNothing);
    expect(find.text('Surah'), findsNothing);
  });
}

class _LuhaidanPreferences extends AppPreferences {
  const _LuhaidanPreferences();

  @override
  Future<String?> get selectedVoiceId async => 'muhammad-al-luhaidan';
}
