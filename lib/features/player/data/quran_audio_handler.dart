import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) '../../../core/platform/unsupported_io.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';

import 'audio_repository.dart';
import '../../repeat/domain/repeat_settings.dart';
import '../../voices/data/surah_audio_catalog.dart';
import '../domain/sleep_timer_controller.dart';

class QuranAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  QuranAudioHandler() {
    _sleepTimer = SleepTimerController(
      onExpire: pause,
      onError: (error, stackTrace) {
        playbackState.addError(error, stackTrace);
      },
    );
    AppLifecycleListener(onResume: _sleepTimer.checkDeadline);
    _player.playbackEventStream.listen(
      (event) => playbackState.add(_transformEvent(event)),
      onError: (Object error, StackTrace stackTrace) {
        playbackState.addError(error, stackTrace);
      },
    );
    _player.currentIndexStream.listen(
      (index) {
        if (index == null || index < 0 || index >= queue.value.length) return;
        mediaItem.add(queue.value[index]);
        _lastPosition = Duration.zero;
        _ignorePositionReset = true;
        _runRepeatTask(_configureLoopModeForIndex(index));
      },
      onError: (Object error, StackTrace stackTrace) {
        playbackState.addError(error, stackTrace);
      },
    );
    _player.positionStream.listen(
      (position) {
        final previousPosition = _lastPosition;
        _lastPosition = position;
        if (_ignorePositionReset) {
          _ignorePositionReset = false;
          return;
        }
        if (_handlingRepeatBoundary ||
            previousPosition <= position ||
            _player.currentIndex != _repeatPlan?.endIndex) {
          return;
        }
        _runRepeatTask(_handleRepeatBoundary());
      },
      onError: (Object error, StackTrace stackTrace) {
        playbackState.addError(error, stackTrace);
      },
    );
  }

  static QuranAudioHandler? _instance;

  static QuranAudioHandler? get instance => _instance;

  static Future<void> initialize() async {
    if (kIsWeb) return;
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
  List<AudioTrack> _tracks = const [];
  List<SurahAudioSource> _surahAudioSources = const [];
  RepeatPlaybackPlan? _repeatPlan;
  int _completedRepeatPasses = 0;
  Duration _lastPosition = Duration.zero;
  bool _handlingRepeatBoundary = false;
  bool _ignorePositionReset = false;
  late final SleepTimerController _sleepTimer;

  List<AudioTrack> get tracks => List.unmodifiable(_tracks);

  bool get hasQueue => _tracks.isNotEmpty || _surahAudioSources.isNotEmpty;

  bool get hasSurahAudioQueue => _surahAudioSources.isNotEmpty;

  int? get currentIndex => _player.currentIndex;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Duration get position => _player.position;

  Duration? get duration => _player.duration;

  double get playbackSpeed => _player.speed;

  Duration? get sleepTimerRemaining => _sleepTimer.remaining;

  Stream<Duration?> get sleepTimerRemainingStream =>
      _sleepTimer.remainingStream;

  void startSleepTimer(Duration duration) => _sleepTimer.start(duration);

  void cancelSleepTimer() => _sleepTimer.cancel();

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

    _repeatPlan = null;
    _completedRepeatPasses = 0;
    _surahAudioSources = const [];
    _tracks = List.unmodifiable(tracks);
    await _player.stop();
    queue.add(items);
    await _player.setAudioSources(
      tracks.map((track) => AudioSource.file(track.filePath)).toList(),
      initialIndex: initialTrack,
    );
    _lastPosition = _player.position;
    mediaItem.add(items[initialTrack]);
  }

  Future<void> loadSurahAudio(
    List<SurahAudioSource> sources, {
    required String voiceName,
    required String voiceId,
    int initialTrack = 0,
  }) async {
    if (sources.length != 114 ||
        sources.indexed.any((entry) => entry.$1 + 1 != entry.$2.number)) {
      throw StateError('Katalog audio harus memuat 114 surah berurutan.');
    }
    if (initialTrack < 0 || initialTrack >= sources.length) {
      throw RangeError.range(
        initialTrack,
        0,
        sources.length - 1,
        'initialTrack',
      );
    }

    final items = sources
        .map(
          (source) => MediaItem(
            id: 'surah-${source.number}',
            title: source.name,
            artist: voiceName,
            album: 'Mode Audio Per Surah',
            extras: {
              'audioMode': 'surah',
              'voiceId': voiceId,
              'surahNumber': source.number,
            },
          ),
        )
        .toList(growable: false);

    _repeatPlan = null;
    _completedRepeatPasses = 0;
    _tracks = const [];
    _surahAudioSources = List.unmodifiable(sources);
    await _player.stop();
    await _player.setLoopMode(LoopMode.off);
    _repeatMode = AudioServiceRepeatMode.none;
    playbackState.add(
      playbackState.value.copyWith(repeatMode: AudioServiceRepeatMode.none),
    );
    await super.setRepeatMode(AudioServiceRepeatMode.none);
    queue.add(items);
    await _player.setAudioSources(
      sources.map((source) => AudioSource.uri(source.uri)).toList(),
      initialIndex: initialTrack,
    );
    _lastPosition = _player.position;
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
  Future<void> seek(Duration position) async {
    if (position < _player.position) _ignorePositionReset = true;
    await _player.seek(position);
    _lastPosition = _player.position;
  }

  @override
  Future<void> skipToNext() async {
    await _cancelFiniteRepeat();
    await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _cancelFiniteRepeat();
    await _player.seekToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) {
      throw RangeError.index(index, queue.value, 'index');
    }
    await _cancelFiniteRepeat();
    _ignorePositionReset = true;
    await _player.seek(Duration.zero, index: index);
    _lastPosition = _player.position;
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (!speed.isFinite || speed < 0.5 || speed > 2.0) {
      throw ArgumentError.value(speed, 'speed', 'Must be between 0.5 and 2.0.');
    }
    await _player.setSpeed(speed);
    playbackState.add(playbackState.value.copyWith(speed: speed));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (hasSurahAudioQueue && repeatMode != AudioServiceRepeatMode.none) {
      throw UnsupportedError(
        'Pengulangan belum tersedia untuk audio per surah.',
      );
    }
    _repeatPlan = null;
    _completedRepeatPasses = 0;
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

  Future<void> applyRepeatSettings(RepeatSettings settings) async {
    if (hasSurahAudioQueue) {
      throw UnsupportedError(
        'Pengulangan ayat atau rentang belum tersedia untuk audio per surah.',
      );
    }
    if (_tracks.isEmpty) {
      throw StateError('Antrean audio belum tersedia untuk pengaturan ulang.');
    }
    final index = _player.currentIndex;
    if (index == null) {
      throw StateError('Tidak ada ayat aktif di antrean audio.');
    }
    final plan = RepeatPlaybackPlan.create(
      settings: settings,
      globalNumbers: _tracks.map((track) => track.globalNumber).toList(),
      surahNumbers: _tracks.map((track) => track.surahNumber).toList(),
      juzNumbers: _tracks.map((track) => track.juzNumber).toList(),
      currentIndex: index,
    );

    _repeatPlan = plan;
    _completedRepeatPasses = 0;
    _repeatMode = switch (settings.mode) {
      RepeatMode.none => AudioServiceRepeatMode.none,
      RepeatMode.ayah => AudioServiceRepeatMode.one,
      RepeatMode.range ||
      RepeatMode.surah ||
      RepeatMode.juz => AudioServiceRepeatMode.group,
      RepeatMode.unlimited => AudioServiceRepeatMode.all,
    };
    await _player.setLoopMode(
      settings.mode == RepeatMode.unlimited
          ? LoopMode.all
          : plan != null && index == plan.endIndex
          ? LoopMode.one
          : LoopMode.off,
    );
    playbackState.add(playbackState.value.copyWith(repeatMode: _repeatMode));
    await super.setRepeatMode(_repeatMode);
    _lastPosition = _player.position;
  }

  Future<void> _configureLoopModeForIndex(int index) async {
    final plan = _repeatPlan;
    if (plan == null) return;
    await _player.setLoopMode(
      index == plan.endIndex ? LoopMode.one : LoopMode.off,
    );
  }

  Future<void> _handleRepeatBoundary() async {
    final plan = _repeatPlan;
    if (plan == null || _handlingRepeatBoundary) return;
    _handlingRepeatBoundary = true;
    try {
      _completedRepeatPasses++;
      final action = plan.actionAfterCompletedPass(
        completedPasses: _completedRepeatPasses,
        queueLength: _tracks.length,
      );
      if (action == RepeatBoundaryAction.repeatScope) {
        if (_player.currentIndex != plan.startIndex) {
          _ignorePositionReset = true;
          await _player.seek(Duration.zero, index: plan.startIndex);
          _lastPosition = _player.position;
        }
        return;
      }

      _repeatPlan = null;
      _completedRepeatPasses = 0;
      _repeatMode = AudioServiceRepeatMode.none;
      await _player.setLoopMode(LoopMode.off);
      playbackState.add(playbackState.value.copyWith(repeatMode: _repeatMode));
      await super.setRepeatMode(_repeatMode);
      if (action == RepeatBoundaryAction.continueQueue) {
        final nextIndex = plan.endIndex + 1;
        _ignorePositionReset = true;
        await _player.seek(Duration.zero, index: nextIndex);
      } else {
        final duration = _player.duration;
        if (duration != null) {
          _ignorePositionReset = true;
          await _player.seek(duration);
        }
        await _player.pause();
      }
      _lastPosition = _player.position;
    } finally {
      _handlingRepeatBoundary = false;
    }
  }

  Future<void> _cancelFiniteRepeat() async {
    if (_repeatPlan == null) return;
    _repeatPlan = null;
    _completedRepeatPasses = 0;
    _repeatMode = AudioServiceRepeatMode.none;
    await _player.setLoopMode(LoopMode.off);
    playbackState.add(playbackState.value.copyWith(repeatMode: _repeatMode));
    await super.setRepeatMode(_repeatMode);
  }

  void _runRepeatTask(Future<void> task) {
    unawaited(task.catchError(_reportRepeatError));
  }

  void _reportRepeatError(Object error, StackTrace stackTrace) {
    playbackState.addError(error, stackTrace);
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
