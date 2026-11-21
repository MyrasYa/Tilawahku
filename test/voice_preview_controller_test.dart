import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/voices/data/voice_catalog.dart';
import 'package:tilawahku/features/voices/data/voice_preview_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'each ayah-based qari preview uses the same sample ayah and metadata',
    () async {
      final voices = await const VoiceCatalog().load();
      final previewVoices = voices
          .where((voice) => voice.audioMode == VoiceAudioMode.ayah)
          .toList();
      final player = _FakeVoicePreviewPlayer();
      final controller = VoicePreviewController(player: player);
      addTearDown(controller.dispose);

      for (final voice in previewVoices) {
        await controller.play(voice);
      }

      expect(player.urls, [
        for (final voice in previewVoices)
          'https://cdn.islamic.network/quran/audio/'
              '${voice.bitrateKbps}/${voice.editionId}/1.mp3',
      ]);
      expect(VoicePreviewController.sampleGlobalAyah, 1);
      expect(controller.state.value.voiceId, previewVoices.last.id);
      expect(controller.state.value.status, VoicePreviewStatus.playing);
    },
  );

  test('surah-based qari cannot use an ayah preview', () async {
    final voice = (await const VoiceCatalog().load()).singleWhere(
      (item) => item.audioMode == VoiceAudioMode.surah,
    );
    final player = _FakeVoicePreviewPlayer();
    final controller = VoicePreviewController(player: player);
    addTearDown(controller.dispose);

    await controller.play(voice);

    expect(player.urls, isEmpty);
    expect(controller.state.value.voiceId, voice.id);
    expect(controller.state.value.status, VoicePreviewStatus.error);
    expect(
      controller.state.value.error,
      contains('Preview ayat tidak tersedia untuk qari audio per surah.'),
    );
  });

  test('changing qari stops current preview before loading the next', () async {
    final voices = await const VoiceCatalog().load();
    final player = _FakeVoicePreviewPlayer();
    final controller = VoicePreviewController(player: player);
    addTearDown(controller.dispose);

    await controller.play(voices[0]);
    await controller.play(voices[1]);

    expect(player.urls, hasLength(2));
    expect(player.stopCount, 2);
    expect(controller.state.value.voiceId, voices[1].id);
    expect(controller.state.value.status, VoicePreviewStatus.playing);
  });

  test(
    'preview exposes loading state until the audio source is ready',
    () async {
      final voice = (await const VoiceCatalog().load()).first;
      final player = _FakeVoicePreviewPlayer()
        ..setUrlCompleter = Completer<void>();
      final controller = VoicePreviewController(player: player);
      addTearDown(controller.dispose);

      final previewFuture = controller.play(voice);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.value.status, VoicePreviewStatus.loading);

      player.setUrlCompleter!.complete();
      await previewFuture;
      expect(controller.state.value.status, VoicePreviewStatus.playing);
    },
  );

  test('URL or network failure is exposed as preview error', () async {
    final voices = await const VoiceCatalog().load();
    final player = _FakeVoicePreviewPlayer()
      ..setUrlError = StateError('network unavailable');
    final controller = VoicePreviewController(player: player);
    addTearDown(controller.dispose);

    await controller.play(voices.first);

    expect(controller.state.value.status, VoicePreviewStatus.error);
    expect(controller.state.value.error, contains('network unavailable'));
  });
}

class _FakeVoicePreviewPlayer implements VoicePreviewPlayer {
  final List<String> urls = [];
  int stopCount = 0;
  bool disposed = false;
  Object? setUrlError;
  Completer<void>? setUrlCompleter;
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
    await setUrlCompleter?.future;
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
