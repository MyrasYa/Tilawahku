import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilawahku/core/preferences/app_preferences.dart';
import 'package:tilawahku/features/voices/data/voice_preview_controller.dart';
import 'package:tilawahku/features/voices/presentation/voice_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'preview is isolated, blocked during main playback, and disposed',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mainPlayback = StreamController<bool>.broadcast();
      addTearDown(mainPlayback.close);
      final player = _FakeVoicePreviewPlayer();
      final controller = VoicePreviewController(player: player);
      var mainAudioPlaying = false;

      await tester.pumpWidget(
        MaterialApp(
          home: VoiceSelectionScreen(
            preferences: const AppPreferences(),
            onSetDarkMode: (_) {},
            previewController: controller,
            isMainAudioPlaying: () => mainAudioPlaying,
            mainAudioPlayingStream: mainPlayback.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('voice-preview-husary')),
      );
      await tester.tap(find.byKey(const ValueKey('voice-preview-husary')));
      await tester.pump();

      expect(controller.state.value.status, VoicePreviewStatus.playing);
      player.setUrlError = StateError('network unavailable');
      await tester.ensureVisible(
        find.byKey(const ValueKey('voice-preview-minshawi')),
      );
      await tester.tap(find.byKey(const ValueKey('voice-preview-minshawi')));
      await tester.pump();
      expect(
        find.textContaining('Preview gagal: Bad state: network unavailable'),
        findsOneWidget,
      );

      player.setUrlError = null;
      await tester.tap(find.byKey(const ValueKey('voice-preview-husary')));
      await tester.pump();
      expect(controller.state.value.status, VoicePreviewStatus.playing);
      final urlsBeforeMainPlayback = List<String>.of(player.urls);
      mainAudioPlaying = true;
      mainPlayback.add(true);
      await tester.pump();
      expect(controller.state.value.status, VoicePreviewStatus.idle);
      expect(player.stopCount, greaterThanOrEqualTo(4));
      expect(player.urls, urlsBeforeMainPlayback);
      expect(
        find.text('Preview dinonaktifkan selama audio utama sedang diputar.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(player.stopCount, greaterThanOrEqualTo(5));
      expect(player.disposed, isTrue);
    },
  );
}

class _FakeVoicePreviewPlayer implements VoicePreviewPlayer {
  final List<String> urls = [];
  int stopCount = 0;
  bool disposed = false;
  Object? setUrlError;
  Completer<void> _playback = Completer<void>();

  @override
  Future<void> stop() async {
    stopCount++;
    if (!_playback.isCompleted) _playback.complete();
  }

  @override
  Future<void> setUrl(String url) async {
    urls.add(url);
    if (setUrlError case final error?) throw error;
  }

  @override
  Future<void> play() {
    _playback = Completer<void>();
    return _playback.future;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
