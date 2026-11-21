import 'dart:io'
    if (dart.library.js_interop) '../../../core/platform/unsupported_io.dart';

import '../../player/data/audio_repository.dart';

class SurahAudioPackage {
  const SurahAudioPackage({
    required this.voiceId,
    required this.surahNumber,
    required this.surahName,
    required this.totalAyahs,
    required this.downloadedAyahs,
    required this.downloadedBytes,
  });

  final String voiceId;
  final int surahNumber;
  final String surahName;
  final int totalAyahs;
  final int downloadedAyahs;
  final int downloadedBytes;

  bool get isComplete => downloadedAyahs == totalAyahs;
}

class SurahAudioRepository {
  SurahAudioRepository({AudioRepository? audioRepository})
    : _audioRepository = audioRepository ?? AudioRepository();

  final AudioRepository _audioRepository;

  Future<List<SurahAudioPackage>> getPackages(String voiceId) async {
    final tracks = await _audioRepository.getAllSurahTracks(voiceId: voiceId);
    if (tracks.isEmpty) {
      throw StateError('Manifest audio untuk suara "$voiceId" tidak tersedia.');
    }

    final groupedTracks = <int, List<AudioTrack>>{};
    for (final track in tracks) {
      groupedTracks.putIfAbsent(track.surahNumber, () => []).add(track);
    }
    if (groupedTracks.length != 114) {
      throw StateError(
        'Manifest audio surah tidak lengkap (${groupedTracks.length}/114).',
      );
    }

    final downloadedCounts = <int, (int, int)>{};
    final allTracks = groupedTracks.values.expand((tracks) => tracks).toList();
    const batchSize = 128;
    for (var offset = 0; offset < allTracks.length; offset += batchSize) {
      final batch = allTracks.skip(offset).take(batchSize);
      final stats = await Future.wait(
        batch.map((track) async {
          final fileStat = await File(track.filePath).stat();
          return (
            track.surahNumber,
            fileStat.type == FileSystemEntityType.file ? fileStat.size : 0,
          );
        }),
      );
      for (final (surahNumber, bytes) in stats) {
        if (bytes == 0) continue;
        final (ayahs, totalBytes) = downloadedCounts[surahNumber] ?? (0, 0);
        downloadedCounts[surahNumber] = (ayahs + 1, totalBytes + bytes);
      }
    }

    final packages = <SurahAudioPackage>[];
    for (final entry in groupedTracks.entries) {
      final (downloadedAyahs, downloadedBytes) =
          downloadedCounts[entry.key] ?? (0, 0);
      packages.add(
        SurahAudioPackage(
          voiceId: voiceId,
          surahNumber: entry.key,
          surahName: entry.value.first.surahName,
          totalAyahs: entry.value.length,
          downloadedAyahs: downloadedAyahs,
          downloadedBytes: downloadedBytes,
        ),
      );
    }
    packages.sort((a, b) => a.surahNumber.compareTo(b.surahNumber));
    return packages;
  }
}
