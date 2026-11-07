import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) '../../../core/platform/unsupported_io.dart';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage_space/storage_space.dart';

import '../../player/data/audio_repository.dart';
import '../../voices/data/voice_audio_source.dart';
import '../../voices/data/voice_catalog.dart';
import 'audio_package_repository.dart';

enum DownloadAction { pause, cancel }

class PackageDownloadProgress {
  const PackageDownloadProgress({
    required this.completedAyahs,
    required this.totalAyahs,
    required this.completedBytes,
    required this.totalBytes,
    this.currentAyahProgress = 0,
  });

  final int completedAyahs;
  final int totalAyahs;
  final int completedBytes;
  final int totalBytes;
  final double currentAyahProgress;

  double get progress {
    if (totalAyahs == 0) return 0;
    return (completedAyahs + currentAyahProgress) / totalAyahs;
  }
}

class SurahDownloadProgress {
  const SurahDownloadProgress({
    required this.completedAyahs,
    required this.totalAyahs,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.status,
    this.currentAyahProgress = 0,
    this.error,
  });

  final int completedAyahs;
  final int totalAyahs;
  final int downloadedBytes;
  final int totalBytes;
  final AudioPackageStatus status;
  final double currentAyahProgress;
  final String? error;

  double get progress => totalAyahs == 0
      ? 0
      : ((completedAyahs + currentAyahProgress) / totalAyahs)
            .clamp(0, 1)
            .toDouble();
}

class AudioDownloadManager extends ChangeNotifier {
  AudioDownloadManager({
    AudioRepository? audioRepository,
    AudioPackageRepository? packageRepository,
    Dio? dio,
  }) : _audioRepository = audioRepository ?? AudioRepository(),
       _packageRepository = packageRepository ?? AudioPackageRepository(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(minutes: 2),
               sendTimeout: const Duration(seconds: 20),
             ),
           );

  static final AudioDownloadManager instance = AudioDownloadManager();

  final AudioRepository _audioRepository;
  final AudioPackageRepository _packageRepository;
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _startingPackages = {};
  final Map<String, DownloadAction> _requestedActions = {};
  final Map<String, PackageDownloadProgress> _progress = {};
  final Map<String, AudioPackageStatus> _statuses = {};
  final Set<String> _estimating = {};
  final Map<String, Future<List<AudioTrack>>> _juzTracks = {};
  final Map<String, (int, int)> _downloadedStats = {};
  final Map<String, SurahDownloadProgress> _surahProgress = {};
  final Map<String, AudioTrack> _currentSurahTracks = {};
  final Map<String, Set<int>> _activeSurahJuz = {};
  final Map<String, int> _surahBaseBytes = {};
  final Set<String> _surahStopRequests = {};
  final Set<String> _estimatingSurahs = {};
  final Map<String, int> _estimatedSurahBytes = {};

  String _key(String voiceId, int juz) => '$voiceId:$juz';
  String _surahKey(String voiceId, int surah) => '$voiceId:surah:$surah';

  PackageDownloadProgress? progressFor(String voiceId, int juz) =>
      _progress[_key(voiceId, juz)];

  AudioPackageStatus? statusFor(String voiceId, int juz) =>
      _statuses[_key(voiceId, juz)];

  bool isEstimating(String voiceId, int juz) =>
      _estimating.contains(_key(voiceId, juz));

  SurahDownloadProgress? surahProgressFor(String voiceId, int surah) =>
      _surahProgress[_surahKey(voiceId, surah)];

  bool isEstimatingSurah(String voiceId, int surah) =>
      _estimatingSurahs.contains(_surahKey(voiceId, surah));

  Future<void> recoverInterruptedDownloads(String voiceId) async {
    if (_cancelTokens.keys.any((key) => key.startsWith('$voiceId:')) ||
        _startingPackages.any((key) => key.startsWith('$voiceId:')) ||
        _activeSurahJuz.keys.any((key) => key.startsWith('$voiceId:'))) {
      return;
    }
    await _packageRepository.recoverInterruptedDownloads(voiceId);
  }

  Future<bool> isAyahDownloaded(AudioTrack track) =>
      _isValidMp3(File(track.filePath));

  Future<List<AudioTrack>> _tracksForJuz({
    required String voiceId,
    required int juz,
  }) async {
    final key = _key(voiceId, juz);
    final tracks = _juzTracks.putIfAbsent(
      key,
      () => _audioRepository.getJuzTracks(juzNumber: juz, voiceId: voiceId),
    );
    try {
      return await tracks;
    } catch (_) {
      _juzTracks.remove(key);
      rethrow;
    }
  }

  List<AudioTrack> _sampleTracks(List<AudioTrack> tracks, int limit) {
    if (tracks.length <= limit) return tracks;
    return List<AudioTrack>.generate(
      limit,
      (index) => tracks[(index * (tracks.length - 1) / (limit - 1)).round()],
      growable: false,
    );
  }

  Future<int> estimatePackageSize({
    required Voice voice,
    required int juz,
    bool sampleOnly = false,
  }) async {
    final key = _key(voice.id, juz);
    if (!_estimating.add(key)) {
      throw StateError('Perkiraan ukuran paket ini sedang dihitung.');
    }
    notifyListeners();
    try {
      final tracks = await _tracksForJuz(voiceId: voice.id, juz: juz);
      if (tracks.isEmpty) {
        throw StateError('Manifest audio juz $juz belum tersedia.');
      }

      var totalBytes = 0;
      const batchSize = 12;
      final tracksToMeasure = sampleOnly
          ? _sampleTracks(tracks, batchSize)
          : tracks;
      for (
        var offset = 0;
        offset < tracksToMeasure.length;
        offset += batchSize
      ) {
        final batch = tracksToMeasure.skip(offset).take(batchSize);
        final sizes = await Future.wait(
          batch.map((track) async {
            final response = await _dio.head<void>(
              _audioUrl(voice, track.globalNumber),
              options: Options(
                followRedirects: true,
                validateStatus: (status) =>
                    status != null && status >= 200 && status < 400,
              ),
            );
            final length =
                int.tryParse(
                  response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
                ) ??
                0;
            if (length <= 0) {
              throw StateError(
                'Server tidak memberikan ukuran audio ayat ${track.globalNumber}.',
              );
            }
            return length;
          }),
        );
        totalBytes += sizes.fold<int>(0, (sum, size) => sum + size);
      }
      if (sampleOnly) {
        totalBytes = (totalBytes / tracksToMeasure.length * tracks.length)
            .ceil();
      }
      await _packageRepository.update(
        voiceId: voice.id,
        juz: juz,
        status: AudioPackageStatus.notDownloaded,
        downloadedAyah: 0,
        downloadedBytes: 0,
        totalBytes: totalBytes,
      );
      _statuses[key] = AudioPackageStatus.notDownloaded;
      return totalBytes;
    } finally {
      _estimating.remove(key);
      notifyListeners();
    }
  }

  Future<int> estimateSurahSize({
    required Voice voice,
    required int surahNumber,
  }) async {
    final key = _surahKey(voice.id, surahNumber);
    final cachedEstimate = _estimatedSurahBytes[key];
    if (cachedEstimate != null) return cachedEstimate;
    if (!_estimatingSurahs.add(key)) {
      throw StateError('Perkiraan ukuran surah ini sedang dihitung.');
    }
    notifyListeners();
    try {
      final tracks = await _audioRepository.getSurahTracks(
        surahNumber: surahNumber,
        voiceId: voice.id,
      );
      if (tracks.isEmpty) {
        throw StateError('Manifest audio Surah $surahNumber tidak tersedia.');
      }

      var totalBytes = 0;
      const batchSize = 12;
      for (var offset = 0; offset < tracks.length; offset += batchSize) {
        final batch = tracks.skip(offset).take(batchSize);
        final sizes = await Future.wait(
          batch.map((track) async {
            final response = await _dio.head<void>(
              _audioUrl(voice, track.globalNumber),
              options: Options(
                followRedirects: true,
                validateStatus: (status) =>
                    status != null && status >= 200 && status < 400,
              ),
            );
            final length = int.tryParse(
              response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
            );
            if (length == null || length <= 0) {
              throw StateError(
                'Server tidak memberikan ukuran audio ayat '
                '${track.globalNumber}.',
              );
            }
            return length;
          }),
        );
        totalBytes += sizes.fold<int>(0, (sum, size) => sum + size);
      }
      _estimatedSurahBytes[key] = totalBytes;
      return totalBytes;
    } finally {
      _estimatingSurahs.remove(key);
      notifyListeners();
    }
  }

  Future<void> downloadPackage({
    required Voice voice,
    required int juz,
    required int totalBytes,
  }) async {
    final key = _key(voice.id, juz);
    if (_activeSurahJuz.isNotEmpty) {
      throw StateError('Tunggu hingga unduhan surah selesai terlebih dahulu.');
    }
    if (_cancelTokens.containsKey(key) || !_startingPackages.add(key)) {
      throw StateError('Paket ini sedang diunduh.');
    }

    late final List<AudioTrack> tracks;
    var completedBytes = 0;
    var completedAyahs = 0;
    try {
      _downloadedStats.remove(key);
      tracks = await _tracksForJuz(voiceId: voice.id, juz: juz);
      if (tracks.isEmpty) {
        throw StateError('Manifest audio juz $juz belum tersedia.');
      }

      for (final track in tracks) {
        final file = File(track.filePath);
        if (await file.exists() && await _isValidMp3(file)) {
          completedAyahs++;
          completedBytes += await file.length();
        }
      }
      _downloadedStats[key] = (completedAyahs, completedBytes);
      final supportDirectory = await getApplicationSupportDirectory();
      await supportDirectory.create(recursive: true);
      final storage = await getStorageSpace(
        lowOnSpaceThreshold: 0,
        fractionDigits: 0,
      );
      final remainingBytes = math.max(totalBytes - completedBytes, 0);
      final neededMiB = remainingBytes / (1024 * 1024);
      if (storage.free < remainingBytes * 1.1) {
        final freeSpaceMiB = storage.free / (1024 * 1024);
        throw StateError(
          'Ruang kosong tidak cukup. Dibutuhkan sekitar '
          '${neededMiB.ceil()} MiB; tersedia ${freeSpaceMiB.floor()} MiB.',
        );
      }

      await _packageRepository.update(
        voiceId: voice.id,
        juz: juz,
        status: AudioPackageStatus.downloading,
        downloadedAyah: completedAyahs,
        downloadedBytes: completedBytes,
        totalBytes: totalBytes,
      );
    } catch (_) {
      _startingPackages.remove(key);
      rethrow;
    }

    final actionBeforeStart = _requestedActions.remove(key);
    if (actionBeforeStart != null) {
      _startingPackages.remove(key);
      await _packageRepository.update(
        voiceId: voice.id,
        juz: juz,
        status: AudioPackageStatus.paused,
        downloadedAyah: completedAyahs,
        downloadedBytes: completedBytes,
        totalBytes: totalBytes,
        error: actionBeforeStart == DownloadAction.cancel
            ? 'Unduhan dibatalkan.'
            : null,
      );
      _statuses[key] = AudioPackageStatus.paused;
      notifyListeners();
      return;
    }

    final token = CancelToken();
    _startingPackages.remove(key);
    _cancelTokens[key] = token;
    _requestedActions.remove(key);
    _statuses[key] = AudioPackageStatus.downloading;
    _progress[key] = PackageDownloadProgress(
      completedAyahs: completedAyahs,
      totalAyahs: tracks.length,
      completedBytes: completedBytes,
      totalBytes: totalBytes,
    );
    notifyListeners();

    try {
      for (final track in tracks) {
        if (token.isCancelled) break;
        final destination = File(track.filePath);
        if (await destination.exists() && await _isValidMp3(destination)) {
          continue;
        }

        final partFile = File('${track.filePath}.part');
        await partFile.parent.create(recursive: true);
        final resumedBytes = await partFile.exists()
            ? await partFile.length()
            : 0;
        var response = await _downloadAyah(
          voice: voice,
          globalAyah: track.globalNumber,
          partFile: partFile,
          cancelToken: token,
          resumedBytes: resumedBytes,
          completedAyahs: completedAyahs,
          totalAyahs: tracks.length,
          completedBytes: completedBytes,
          totalBytes: totalBytes,
          progressKey: key,
        );

        if (resumedBytes > 0 &&
            response.statusCode != HttpStatus.partialContent) {
          if (await partFile.exists()) await partFile.delete();
          response = await _downloadAyah(
            voice: voice,
            globalAyah: track.globalNumber,
            partFile: partFile,
            cancelToken: token,
            resumedBytes: 0,
            completedAyahs: completedAyahs,
            totalAyahs: tracks.length,
            completedBytes: completedBytes,
            totalBytes: totalBytes,
            progressKey: key,
          );
        }

        if (response.statusCode != HttpStatus.ok &&
            response.statusCode != HttpStatus.partialContent) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            message: 'Server mengembalikan HTTP ${response.statusCode}.',
          );
        }
        if (!await _isValidMp3(partFile)) {
          throw FormatException(
            'Respons audio ayat ${track.globalNumber} bukan MP3 yang valid.',
          );
        }

        await partFile.rename(destination.path);
        completedAyahs++;
        completedBytes += await destination.length();
        _downloadedStats[key] = (completedAyahs, completedBytes);
        _progress[key] = PackageDownloadProgress(
          completedAyahs: completedAyahs,
          totalAyahs: tracks.length,
          completedBytes: completedBytes,
          totalBytes: totalBytes,
        );
        await _packageRepository.update(
          voiceId: voice.id,
          juz: juz,
          status: AudioPackageStatus.downloading,
          downloadedAyah: completedAyahs,
          downloadedBytes: completedBytes,
          totalBytes: totalBytes,
        );
        notifyListeners();
      }

      final action = _requestedActions[key];
      if (action != null) {
        if (action == DownloadAction.cancel) {
          await _deletePartialFiles(tracks);
        }
        await _packageRepository.update(
          voiceId: voice.id,
          juz: juz,
          status: AudioPackageStatus.paused,
          downloadedAyah: completedAyahs,
          downloadedBytes: completedBytes,
          totalBytes: totalBytes,
          error: action == DownloadAction.cancel ? 'Unduhan dibatalkan.' : null,
        );
        _statuses[key] = AudioPackageStatus.paused;
      } else {
        await _packageRepository.update(
          voiceId: voice.id,
          juz: juz,
          status: AudioPackageStatus.complete,
          downloadedAyah: tracks.length,
          downloadedBytes: completedBytes,
          totalBytes: totalBytes,
        );
        _statuses[key] = AudioPackageStatus.complete;
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        final action = _requestedActions[key];
        if (action == DownloadAction.cancel) {
          await _deletePartialFiles(tracks);
        }
        await _packageRepository.update(
          voiceId: voice.id,
          juz: juz,
          status: AudioPackageStatus.paused,
          downloadedAyah: completedAyahs,
          downloadedBytes: completedBytes,
          totalBytes: totalBytes,
          error: action == DownloadAction.cancel ? 'Unduhan dibatalkan.' : null,
        );
        _statuses[key] = AudioPackageStatus.paused;
      } else {
        await _markFailed(
          voice: voice,
          juz: juz,
          tracks: tracks,
          totalBytes: totalBytes,
          error: error.message ?? error.toString(),
        );
        rethrow;
      }
    } catch (error) {
      await _markFailed(
        voice: voice,
        juz: juz,
        tracks: tracks,
        totalBytes: totalBytes,
        error: error.toString(),
      );
      rethrow;
    } finally {
      _cancelTokens.remove(key);
      _requestedActions.remove(key);
      notifyListeners();
    }
  }

  Future<void> downloadAyah({
    required Voice voice,
    required AudioTrack track,
  }) => _downloadAyahTrack(voice: voice, track: track);

  Future<void> _downloadAyahTrack({
    required Voice voice,
    required AudioTrack track,
    String? surahKey,
  }) async {
    final key = _key(voice.id, track.juzNumber);
    if (_activeSurahJuz.entries.any(
      (entry) => entry.key != surahKey && entry.value.contains(track.juzNumber),
    )) {
      throw StateError(
        'Audio sedang diunduh sebagai bagian surah. Tunggu hingga selesai.',
      );
    }
    if (_cancelTokens.containsKey(key) || !_startingPackages.add(key)) {
      throw StateError('Audio Juz ${track.juzNumber} sedang diunduh.');
    }

    try {
      final tracks = await _tracksForJuz(
        voiceId: voice.id,
        juz: track.juzNumber,
      );
      if (!tracks.any((item) => item.globalNumber == track.globalNumber)) {
        throw StateError('Manifest audio ayat ini tidak tersedia.');
      }
      final package = await _packageRepository.getPackage(
        voiceId: voice.id,
        juz: track.juzNumber,
      );
      final destination = File(track.filePath);
      if (await _isValidMp3(destination)) {
        final (downloadedAyahs, downloadedBytes) = await _countDownloadedTracks(
          tracks,
        );
        _downloadedStats[key] = (downloadedAyahs, downloadedBytes);
        final complete = downloadedAyahs == tracks.length;
        final totalBytes = package.totalBytes > 0
            ? package.totalBytes
            : complete
            ? downloadedBytes
            : null;
        await _packageRepository.update(
          voiceId: voice.id,
          juz: track.juzNumber,
          status: complete
              ? AudioPackageStatus.complete
              : AudioPackageStatus.notDownloaded,
          downloadedAyah: downloadedAyahs,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
        );
        _statuses[key] = complete
            ? AudioPackageStatus.complete
            : AudioPackageStatus.notDownloaded;
        _progress[key] = PackageDownloadProgress(
          completedAyahs: downloadedAyahs,
          totalAyahs: tracks.length,
          completedBytes: downloadedBytes,
          totalBytes: totalBytes ?? 0,
        );
        notifyListeners();
        return;
      }

      final (completedAyahs, completedBytes) = _downloadedStats[key] ??=
          await _countDownloadedTracks(tracks);
      final token = CancelToken();
      _cancelTokens[key] = token;
      _statuses[key] = AudioPackageStatus.downloading;
      _progress[key] = PackageDownloadProgress(
        completedAyahs: completedAyahs,
        totalAyahs: tracks.length,
        completedBytes: completedBytes,
        totalBytes: package.totalBytes,
      );
      await _packageRepository.update(
        voiceId: voice.id,
        juz: track.juzNumber,
        status: AudioPackageStatus.downloading,
        downloadedAyah: completedAyahs,
        downloadedBytes: completedBytes,
        totalBytes: package.totalBytes,
      );
      notifyListeners();

      final partFile = File('${track.filePath}.part');
      await partFile.parent.create(recursive: true);
      if (await partFile.exists()) await partFile.delete();
      final response = await _dio.download(
        _audioUrl(voice, track.globalNumber),
        partFile.path,
        cancelToken: token,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          final currentBytes = received > 0 ? received : 0;
          final currentProgress = total > 0
              ? (currentBytes / total).clamp(0.0, 1.0)
              : 0.0;
          _progress[key] = PackageDownloadProgress(
            completedAyahs: completedAyahs,
            totalAyahs: tracks.length,
            completedBytes: completedBytes + currentBytes,
            totalBytes: package.totalBytes,
            currentAyahProgress: currentProgress,
          );
          for (final entry in _currentSurahTracks.entries) {
            if (entry.value.globalNumber != track.globalNumber) continue;
            final surahProgress = _surahProgress[entry.key];
            if (surahProgress == null) continue;
            _surahProgress[entry.key] = SurahDownloadProgress(
              completedAyahs: surahProgress.completedAyahs,
              totalAyahs: surahProgress.totalAyahs,
              downloadedBytes:
                  (_surahBaseBytes[entry.key] ??
                      surahProgress.downloadedBytes) +
                  currentBytes,
              totalBytes: surahProgress.totalBytes,
              status: surahProgress.status,
              currentAyahProgress: currentProgress,
            );
          }
          notifyListeners();
        },
      );
      if (response.statusCode != HttpStatus.ok) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Server mengembalikan HTTP ${response.statusCode}.',
        );
      }
      if (!await _isValidMp3(partFile)) {
        throw FormatException(
          'Respons audio ayat ${track.globalNumber} bukan MP3 yang valid.',
        );
      }
      await partFile.rename(destination.path);

      final downloadedAyahs = completedAyahs + 1;
      final downloadedBytes = completedBytes + await destination.length();
      _downloadedStats[key] = (downloadedAyahs, downloadedBytes);
      final complete = downloadedAyahs == tracks.length;
      final totalBytes = package.totalBytes > 0
          ? package.totalBytes
          : complete
          ? downloadedBytes
          : null;
      await _packageRepository.update(
        voiceId: voice.id,
        juz: track.juzNumber,
        status: complete
            ? AudioPackageStatus.complete
            : AudioPackageStatus.notDownloaded,
        downloadedAyah: downloadedAyahs,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
      );
      _statuses[key] = complete
          ? AudioPackageStatus.complete
          : AudioPackageStatus.notDownloaded;
      _progress[key] = PackageDownloadProgress(
        completedAyahs: downloadedAyahs,
        totalAyahs: tracks.length,
        completedBytes: downloadedBytes,
        totalBytes: totalBytes ?? 0,
      );
    } catch (error) {
      final tracks = await _tracksForJuz(
        voiceId: voice.id,
        juz: track.juzNumber,
      );
      final (downloadedAyahs, downloadedBytes) = await _countDownloadedTracks(
        tracks,
      );
      final cancelled = error is DioException && CancelToken.isCancel(error);
      final status = cancelled
          ? AudioPackageStatus.paused
          : AudioPackageStatus.failed;
      await _packageRepository.update(
        voiceId: voice.id,
        juz: track.juzNumber,
        status: status,
        downloadedAyah: downloadedAyahs,
        downloadedBytes: downloadedBytes,
        error: cancelled ? null : error.toString(),
      );
      _statuses[key] = status;
      _downloadedStats[key] = (downloadedAyahs, downloadedBytes);
      rethrow;
    } finally {
      final partFile = File('${track.filePath}.part');
      if (await partFile.exists()) await partFile.delete();
      _cancelTokens.remove(key);
      _requestedActions.remove(key);
      _startingPackages.remove(key);
      notifyListeners();
    }
  }

  Future<void> downloadSurah({
    required Voice voice,
    required int surahNumber,
    required int totalBytes,
  }) async {
    final key = _surahKey(voice.id, surahNumber);
    if (_activeSurahJuz.isNotEmpty ||
        _surahProgress[key]?.status == AudioPackageStatus.downloading) {
      throw StateError('Surah ini sedang diunduh.');
    }

    final tracks = await _audioRepository.getSurahTracks(
      surahNumber: surahNumber,
      voiceId: voice.id,
    );
    if (tracks.isEmpty) {
      throw StateError('Manifest audio Surah $surahNumber tidak tersedia.');
    }
    final juzNumbers = tracks.map((track) => track.juzNumber).toSet();
    if (_cancelTokens.isNotEmpty || _startingPackages.isNotEmpty) {
      throw StateError(
        'Jeda unduhan Juz yang sedang berjalan sebelum mengunduh surah.',
      );
    }

    _activeSurahJuz[key] = juzNumbers;
    try {
      final (initialAyahs, initialBytes) = await _countDownloadedTracks(tracks);
      final storage = await getStorageSpace(
        lowOnSpaceThreshold: 0,
        fractionDigits: 0,
      );
      final remainingBytes = math.max(totalBytes - initialBytes, 0);
      if (storage.free < remainingBytes * 1.1) {
        final neededMiB = remainingBytes / (1024 * 1024);
        final freeSpaceMiB = storage.free / (1024 * 1024);
        throw StateError(
          'Ruang kosong tidak cukup. Dibutuhkan sekitar '
          '${neededMiB.ceil()} MiB; tersedia ${freeSpaceMiB.floor()} MiB.',
        );
      }
      var completedAyahs = initialAyahs;
      var downloadedBytes = initialBytes;
      _surahStopRequests.remove(key);
      _surahProgress[key] = SurahDownloadProgress(
        completedAyahs: completedAyahs,
        totalAyahs: tracks.length,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        status: AudioPackageStatus.downloading,
      );
      notifyListeners();

      try {
        for (final track in tracks) {
          if (_surahStopRequests.contains(key)) break;
          if (await _isValidMp3(File(track.filePath))) continue;
          if (_surahStopRequests.contains(key)) break;

          _surahBaseBytes[key] = downloadedBytes;
          _currentSurahTracks[key] = track;
          try {
            await _downloadAyahTrack(voice: voice, track: track, surahKey: key);
          } catch (error) {
            if (_surahStopRequests.contains(key) &&
                error is DioException &&
                CancelToken.isCancel(error)) {
              break;
            }
            rethrow;
          } finally {
            _currentSurahTracks.remove(key);
            _surahBaseBytes.remove(key);
          }

          completedAyahs++;
          downloadedBytes += await File(track.filePath).length();
          _surahProgress[key] = SurahDownloadProgress(
            completedAyahs: completedAyahs,
            totalAyahs: tracks.length,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            status: AudioPackageStatus.downloading,
          );
          notifyListeners();
        }

        final paused = _surahStopRequests.contains(key);
        _surahProgress[key] = SurahDownloadProgress(
          completedAyahs: completedAyahs,
          totalAyahs: tracks.length,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          status: paused
              ? AudioPackageStatus.paused
              : AudioPackageStatus.complete,
        );
      } catch (error) {
        _surahProgress[key] = SurahDownloadProgress(
          completedAyahs: completedAyahs,
          totalAyahs: tracks.length,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          status: AudioPackageStatus.failed,
          error: error.toString(),
        );
        rethrow;
      }
    } finally {
      _currentSurahTracks.remove(key);
      _activeSurahJuz.remove(key);
      _surahStopRequests.remove(key);
      notifyListeners();
    }
  }

  void pauseSurah({required String voiceId, required int surahNumber}) {
    final key = _surahKey(voiceId, surahNumber);
    if (_surahProgress[key]?.status != AudioPackageStatus.downloading) return;
    _surahStopRequests.add(key);
    final currentTrack = _currentSurahTracks[key];
    if (currentTrack != null) {
      _cancelTokens[_key(voiceId, currentTrack.juzNumber)]?.cancel(
        'Surah download paused',
      );
    }
    notifyListeners();
  }

  Future<void> deleteSurah({
    required Voice voice,
    required int surahNumber,
  }) async {
    final key = _surahKey(voice.id, surahNumber);
    if (_activeSurahJuz.isNotEmpty ||
        _surahProgress[key]?.status == AudioPackageStatus.downloading) {
      throw StateError('Jeda unduhan surah sebelum menghapus audio.');
    }
    final tracks = await _audioRepository.getSurahTracks(
      surahNumber: surahNumber,
      voiceId: voice.id,
    );
    if (tracks.isEmpty) {
      throw StateError('Manifest audio Surah $surahNumber tidak tersedia.');
    }
    for (final juz in tracks.map((track) => track.juzNumber).toSet()) {
      final juzKey = _key(voice.id, juz);
      if (_cancelTokens.containsKey(juzKey) ||
          _startingPackages.contains(juzKey)) {
        throw StateError(
          'Jeda unduhan Juz $juz yang sedang berjalan sebelum menghapus surah.',
        );
      }
    }

    for (final track in tracks) {
      final file = File(track.filePath);
      if (await file.exists()) await file.delete();
      final partialFile = File('${track.filePath}.part');
      if (await partialFile.exists()) await partialFile.delete();
    }
    for (final juz in tracks.map((track) => track.juzNumber).toSet()) {
      await _refreshJuzPackage(voice: voice, juz: juz);
    }
    _surahProgress.remove(key);
    _estimatedSurahBytes.remove(key);
    notifyListeners();
  }

  Future<void> _refreshJuzPackage({
    required Voice voice,
    required int juz,
  }) async {
    final tracks = await _tracksForJuz(voiceId: voice.id, juz: juz);
    final (downloadedAyahs, downloadedBytes) = await _countDownloadedTracks(
      tracks,
    );
    final key = _key(voice.id, juz);
    final package = await _packageRepository.getPackage(
      voiceId: voice.id,
      juz: juz,
    );
    final complete = downloadedAyahs == tracks.length;
    await _packageRepository.update(
      voiceId: voice.id,
      juz: juz,
      status: complete
          ? AudioPackageStatus.complete
          : AudioPackageStatus.notDownloaded,
      downloadedAyah: downloadedAyahs,
      downloadedBytes: downloadedBytes,
      totalBytes: package.totalBytes > 0 ? package.totalBytes : null,
    );
    _statuses[key] = complete
        ? AudioPackageStatus.complete
        : AudioPackageStatus.notDownloaded;
    _progress[key] = PackageDownloadProgress(
      completedAyahs: downloadedAyahs,
      totalAyahs: tracks.length,
      completedBytes: downloadedBytes,
      totalBytes: package.totalBytes,
    );
    _downloadedStats[key] = (downloadedAyahs, downloadedBytes);
  }

  Future<(int, int)> _countDownloadedTracks(List<AudioTrack> tracks) async {
    var downloadedAyahs = 0;
    var downloadedBytes = 0;
    for (final item in tracks) {
      final file = File(item.filePath);
      if (await _isValidMp3(file)) {
        downloadedAyahs++;
        downloadedBytes += await file.length();
      }
    }
    return (downloadedAyahs, downloadedBytes);
  }

  Future<Response<dynamic>> _downloadAyah({
    required Voice voice,
    required int globalAyah,
    required File partFile,
    required CancelToken cancelToken,
    required int resumedBytes,
    required int completedAyahs,
    required int totalAyahs,
    required int completedBytes,
    required int totalBytes,
    required String progressKey,
  }) => _dio.download(
    _audioUrl(voice, globalAyah),
    partFile.path,
    cancelToken: cancelToken,
    deleteOnError: false,
    fileAccessMode: resumedBytes > 0
        ? FileAccessMode.append
        : FileAccessMode.write,
    options: Options(
      headers: {
        if (resumedBytes > 0) HttpHeaders.rangeHeader: 'bytes=$resumedBytes-',
      },
    ),
    onReceiveProgress: (received, total) {
      final expectedAyahBytes = total > 0 ? resumedBytes + total : 0;
      final currentAyahBytes = resumedBytes + (received > 0 ? received : 0);
      final currentProgress = expectedAyahBytes > 0
          ? (currentAyahBytes / expectedAyahBytes).clamp(0.0, 1.0)
          : 0.0;
      _progress[progressKey] = PackageDownloadProgress(
        completedAyahs: completedAyahs,
        totalAyahs: totalAyahs,
        completedBytes: completedBytes + currentAyahBytes,
        totalBytes: totalBytes,
        currentAyahProgress: currentProgress,
      );
      notifyListeners();
    },
  );

  String _audioUrl(Voice voice, int globalAyah) =>
      VoiceAudioSource.urlFor(voice, globalAyah);

  Future<bool> _isValidMp3(File file) async {
    if (!await file.exists() || await file.length() < 4) return false;
    final bytes = await file.openRead(0, 4).first;
    if (bytes.length < 2) return false;
    final hasId3Header =
        bytes.length >= 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33;
    final hasMpegFrameHeader = bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
    return hasId3Header || hasMpegFrameHeader;
  }

  Future<void> pausePackage({required String voiceId, required int juz}) async {
    final key = _key(voiceId, juz);
    _requestedActions[key] = DownloadAction.pause;
    _cancelTokens[key]?.cancel('Paused by user');
  }

  Future<void> cancelPackage({
    required String voiceId,
    required int juz,
  }) async {
    final key = _key(voiceId, juz);
    _requestedActions[key] = DownloadAction.cancel;
    _cancelTokens[key]?.cancel('Cancelled by user');
  }

  Future<void> deletePackage({required Voice voice, required int juz}) async {
    final key = _key(voice.id, juz);
    if (_activeSurahJuz.isNotEmpty ||
        _cancelTokens.containsKey(key) ||
        _startingPackages.contains(key)) {
      throw StateError('Jeda atau batalkan unduhan sebelum menghapus paket.');
    }
    final juzTracks = await _tracksForJuz(voiceId: voice.id, juz: juz);
    for (final track in juzTracks) {
      final file = File(track.filePath);
      if (await file.exists()) await file.delete();
      final partialFile = File('${track.filePath}.part');
      if (await partialFile.exists()) await partialFile.delete();
    }
    await _packageRepository.reset(voiceId: voice.id, juz: juz);
    _progress.remove(key);
    _statuses[key] = AudioPackageStatus.notDownloaded;
    _downloadedStats.remove(key);
    _surahProgress.clear();
    notifyListeners();
  }

  Future<void> _deletePartialFiles(List<AudioTrack> tracks) async {
    for (final track in tracks) {
      final file = File('${track.filePath}.part');
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _markFailed({
    required Voice voice,
    required int juz,
    required List<AudioTrack> tracks,
    required int totalBytes,
    required String error,
  }) async {
    final (downloadedAyah, downloadedBytes) = await _countDownloadedTracks(
      tracks,
    );
    _downloadedStats[_key(voice.id, juz)] = (downloadedAyah, downloadedBytes);
    await _packageRepository.update(
      voiceId: voice.id,
      juz: juz,
      status: AudioPackageStatus.failed,
      downloadedAyah: downloadedAyah,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      error: error,
    );
    _statuses[_key(voice.id, juz)] = AudioPackageStatus.failed;
  }
}
