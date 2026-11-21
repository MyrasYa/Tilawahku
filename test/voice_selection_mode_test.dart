import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/voices/data/voice_preview_controller.dart';
import 'package:tilawahku/features/voices/presentation/voice_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('qari list identifies and selects surah-based audio', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = VoicePreviewController(
      player: _NoopVoicePreviewPlayer(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSelectionScreen(
          preferences: const AppPreferences(),
          onSetDarkMode: (_) {},
          previewController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audio Per Ayat'), findsWidgets);
    final luhaidanName = find.text('Muhammad Al-Luhaidan');
    await tester.scrollUntilVisible(
      luhaidanName,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    final luhaidanCard = find.byKey(
      const ValueKey('voice-selection-muhammad-al-luhaidan'),
    );
    expect(find.text('Audio Per Surah'), findsOneWidget);
    expect(
      find.textContaining(
        'Memutar satu surah secara utuh. Pengulangan ayat atau rentang ayat',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('voice-preview-muhammad-al-luhaidan')),
      findsNothing,
    );
    await tester.tap(luhaidanCard);
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _NoopVoicePreviewPlayer implements VoicePreviewPlayer {
  @override
  Future<void> stop() async {}

  @override
  Future<void> setUrl(String url) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> dispose() async {}
}
