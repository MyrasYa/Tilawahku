enum RepeatMode { none, ayah, range, surah, juz, unlimited }

enum RepeatBoundaryAction { repeatScope, continueQueue, stop }

class RepeatSettings {
  const RepeatSettings({
    required this.mode,
    this.repeatCount = 3,
    this.rangeStart,
    this.rangeEnd,
  });

  final RepeatMode mode;
  final int repeatCount;
  final int? rangeStart;
  final int? rangeEnd;

  RepeatSettings copyWith({
    RepeatMode? mode,
    int? repeatCount,
    int? rangeStart,
    int? rangeEnd,
  }) => RepeatSettings(
    mode: mode ?? this.mode,
    repeatCount: repeatCount ?? this.repeatCount,
    rangeStart: rangeStart ?? this.rangeStart,
    rangeEnd: rangeEnd ?? this.rangeEnd,
  );
}

class RepeatPlaybackPlan {
  const RepeatPlaybackPlan({
    required this.mode,
    required this.startIndex,
    required this.endIndex,
    required this.repeatCount,
  });

  final RepeatMode mode;
  final int startIndex;
  final int endIndex;
  final int repeatCount;

  RepeatBoundaryAction actionAfterCompletedPass({
    required int completedPasses,
    required int queueLength,
  }) {
    if (completedPasses < repeatCount) {
      return RepeatBoundaryAction.repeatScope;
    }
    return endIndex + 1 < queueLength
        ? RepeatBoundaryAction.continueQueue
        : RepeatBoundaryAction.stop;
  }

  static RepeatPlaybackPlan? create({
    required RepeatSettings settings,
    required List<int> globalNumbers,
    required List<int> surahNumbers,
    required List<int> juzNumbers,
    required int currentIndex,
  }) {
    if (globalNumbers.isEmpty ||
        globalNumbers.length != surahNumbers.length ||
        globalNumbers.length != juzNumbers.length) {
      throw StateError('Antrean audio kosong atau metadata tidak lengkap.');
    }
    if (currentIndex < 0 || currentIndex >= globalNumbers.length) {
      throw RangeError.index(currentIndex, globalNumbers, 'currentIndex');
    }
    if (settings.repeatCount < 1 || settings.repeatCount > 100) {
      throw RangeError.range(settings.repeatCount, 1, 100, 'repeatCount');
    }

    final startIndex = switch (settings.mode) {
      RepeatMode.none || RepeatMode.unlimited => null,
      RepeatMode.ayah => currentIndex,
      RepeatMode.range => _findGlobalIndex(
        globalNumbers,
        settings.rangeStart,
        'Ayat awal',
      ),
      RepeatMode.surah => _firstIndex(surahNumbers, surahNumbers[currentIndex]),
      RepeatMode.juz => _firstIndex(juzNumbers, juzNumbers[currentIndex]),
    };
    if (startIndex == null) return null;

    final endIndex = switch (settings.mode) {
      RepeatMode.none || RepeatMode.unlimited => null,
      RepeatMode.ayah => currentIndex,
      RepeatMode.range => _findGlobalIndex(
        globalNumbers,
        settings.rangeEnd,
        'Ayat akhir',
      ),
      RepeatMode.surah => _lastIndex(surahNumbers, surahNumbers[currentIndex]),
      RepeatMode.juz => _lastIndex(juzNumbers, juzNumbers[currentIndex]),
    };
    if (endIndex == null || startIndex > endIndex) {
      throw StateError('Rentang ayat tidak valid untuk antrean saat ini.');
    }
    if (settings.mode == RepeatMode.surah &&
        surahNumbers
            .skip(startIndex)
            .take(endIndex - startIndex + 1)
            .any((number) => number != surahNumbers[currentIndex])) {
      throw StateError('Antrean tidak memuat surah aktif secara berurutan.');
    }
    if (settings.mode == RepeatMode.juz &&
        juzNumbers
            .skip(startIndex)
            .take(endIndex - startIndex + 1)
            .any((number) => number != juzNumbers[currentIndex])) {
      throw StateError('Antrean tidak memuat juz aktif secara berurutan.');
    }
    if (settings.mode == RepeatMode.range &&
        (startIndex > currentIndex ||
            currentIndex > endIndex ||
            globalNumbers[startIndex] > globalNumbers[endIndex])) {
      throw StateError('Rentang harus mencakup ayat aktif di antrean.');
    }
    for (var index = startIndex + 1; index <= endIndex; index++) {
      if (globalNumbers[index] != globalNumbers[index - 1] + 1) {
        throw StateError('Rentang audio tidak lengkap pada antrean saat ini.');
      }
    }

    return RepeatPlaybackPlan(
      mode: settings.mode,
      startIndex: startIndex,
      endIndex: endIndex,
      repeatCount: settings.repeatCount,
    );
  }

  static int _findGlobalIndex(
    List<int> globalNumbers,
    int? globalNumber,
    String label,
  ) {
    if (globalNumber == null) {
      throw StateError('$label belum dipilih.');
    }
    final index = globalNumbers.indexOf(globalNumber);
    if (index < 0) throw StateError('$label tidak ada di antrean audio.');
    return index;
  }

  static int _firstIndex(List<int> values, int value) => values.indexOf(value);

  static int _lastIndex(List<int> values, int value) =>
      values.lastIndexOf(value);
}
