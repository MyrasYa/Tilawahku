import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'voice_audio_source.dart';
import 'voice_catalog.dart';

enum VoicePreviewStatus { idle, loading, playing, error }

class VoicePreviewState {
  const VoicePreviewState({
    this.voiceId,
    this.status = VoicePreviewStatus.idle,
    this.error,
  });

  final String? voiceId;
  final VoicePreviewStatus status;
  final String? error;
}

abstract interface class VoicePreviewPlayer {
  Future<void> stop();

  Future<void> setUrl(String url);

  Future<void> play();

  Future<void> dispose();
}

class _JustAudioVoicePreviewPlayer implements VoicePreviewPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> dispose() => _player.dispose();
}

class _UnavailableVoicePreviewPlayer implements VoicePreviewPlayer {
  @override
  Future<void> stop() async {}

  @override
  Future<void> setUrl(String url) => Future.error(
    UnsupportedError('Audio preview tidak tersedia di Web preview.'),
  );

  @override
  Future<void> play() => Future.error(
    UnsupportedError('Audio preview tidak tersedia di Web preview.'),
  );

  @override
  Future<void> dispose() async {}
}

class VoicePreviewController {
  VoicePreviewController({VoicePreviewPlayer? player, bool enabled = true})
    : _player =
          player ??
          (enabled
              ? _JustAudioVoicePreviewPlayer()
              : _UnavailableVoicePreviewPlayer());

  static const sampleGlobalAyah = 1;

  final VoicePreviewPlayer _player;
  final ValueNotifier<VoicePreviewState> state = ValueNotifier(
    const VoicePreviewState(),
  );
  int _operationId = 0;
  bool _disposed = false;

  static Uri previewUri(Voice voice) {
    if (voice.status != VoiceStatus.active) {
      throw StateError('Preview tidak tersedia untuk qari ini.');
    }
    if (voice.editionId.trim().isEmpty || voice.bitrateKbps <= 0) {
      throw FormatException('Metadata sumber audio qari tidak valid.');
    }
    return Uri.parse(VoiceAudioSource.urlFor(voice, sampleGlobalAyah));
  }

  Future<void> play(Voice voice) async {
    if (_disposed) throw StateError('Preview audio sudah ditutup.');
    final operationId = ++_operationId;
    state.value = VoicePreviewState(
      voiceId: voice.id,
      status: VoicePreviewStatus.loading,
    );
    try {
      final url = previewUri(voice).toString();
      await _player.stop();
      if (!_isCurrent(operationId)) return;
      await _player.setUrl(url);
      if (!_isCurrent(operationId)) return;
      state.value = VoicePreviewState(
        voiceId: voice.id,
        status: VoicePreviewStatus.playing,
      );
      unawaited(_startPlayback(operationId, voice.id));
    } catch (error) {
      if (_isCurrent(operationId)) {
        state.value = VoicePreviewState(
          voiceId: voice.id,
          status: VoicePreviewStatus.error,
          error: error.toString(),
        );
      }
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    _operationId++;
    state.value = const VoicePreviewState();
    await _player.stop();
  }

  bool _isCurrent(int operationId) => !_disposed && operationId == _operationId;

  Future<void> _startPlayback(int operationId, String voiceId) async {
    try {
      await _player.play();
      if (_isCurrent(operationId)) {
        state.value = const VoicePreviewState();
      }
    } catch (error) {
      if (_isCurrent(operationId)) {
        state.value = VoicePreviewState(
          voiceId: voiceId,
          status: VoicePreviewStatus.error,
          error: error.toString(),
        );
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _operationId++;
    state.value = const VoicePreviewState();
    try {
      await _player.stop();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('while stopping qari preview on dispose'),
        ),
      );
    } finally {
      try {
        await _player.dispose();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            context: ErrorDescription('while disposing qari preview player'),
          ),
        );
      } finally {
        state.dispose();
      }
    }
  }
}
