import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_repository.dart';

class QuranAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  QuranAudioHandler() {
    _player.playbackEventStream.listen(
      (event) => playbackState.add(_transformEvent(event)),
      onError: (Object error, StackTrace stackTrace) {
        playbackState.addError(error, stackTrace);
      },
    );
    _player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= queue.value.length) return;
      mediaItem.add(queue.value[index]);
    });
  }

  static QuranAudioHandler? _instance;

  static QuranAudioHandler? get instance => _instance;

  static Future<void> initialize() async {
    if (_instance != null) return;
    final handler = QuranAudioHandler();
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'id.tilawahku.audio',
        androidNotificationChannelName: 'Tilawahku',
        androidNotificationOngoing: true,
      ),
    );
    _instance = handler;
  }

  final AudioPlayer _player = AudioPlayer();
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Duration get position => _player.position;

  Duration? get duration => _player.duration;

  Future<void> loadTracks(
    List<AudioTrack> tracks, {
    required String voiceName,
    required String voiceId,
    int initialTrack = 0,
  }) async {
    if (tracks.isEmpty) {
      throw StateError('Belum ada audio lokal untuk pilihan ini.');
    }
    if (initialTrack < 0 || initialTrack >= tracks.length) {
      throw RangeError.range(
        initialTrack,
        0,
        tracks.length - 1,
        'initialTrack',
      );
    }

    final missingFiles = <String>[];
    for (final track in tracks) {
      if (!await File(track.filePath).exists()) {
        missingFiles.add(track.relativeFileName);
      }
    }
    if (missingFiles.isNotEmpty) {
      throw FileSystemException(
        'Sebagian audio belum diunduh',
        missingFiles.take(3).join(', '),
      );
    }

    final items = tracks
        .map(
          (track) => MediaItem(
            id: track.globalNumber.toString(),
            title: track.title,
            artist: voiceName,
            album: 'Surah ${track.surahNumber} · Juz ${track.juzNumber}',
            extras: {
              'globalNumber': track.globalNumber,
              'voiceId': voiceId,
              'surahNumber': track.surahNumber,
              'ayahNumber': track.ayahNumber,
              'juzNumber': track.juzNumber,
            },
          ),
        )
        .toList(growable: false);

    await _player.stop();
    queue.add(items);
    await _player.setAudioSources(
      tracks.map((track) => AudioSource.file(track.filePath)).toList(),
      initialIndex: initialTrack,
    );
    mediaItem.add(items[initialTrack]);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) {
      throw RangeError.index(index, queue.value, 'index');
    }
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => LoopMode.all,
      AudioServiceRepeatMode.none => LoopMode.off,
    });
    _repeatMode = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: _repeatMode));
    await super.setRepeatMode(repeatMode);
  }

  PlaybackState _transformEvent(PlaybackEvent event) => PlaybackState(
    controls: [
      MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ],
    systemActions: const {MediaAction.seek},
    androidCompactActionIndices: const [0, 1, 2],
    processingState: switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    },
    playing: _player.playing,
    updatePosition: _player.position,
    bufferedPosition: _player.bufferedPosition,
    speed: _player.speed,
    queueIndex: event.currentIndex,
    repeatMode: _repeatMode,
  );
}
