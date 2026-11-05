enum RepeatMode {
  none,
  ayah,
  range,
  surah,
  juz,
  unlimited,
}

class RepeatSettings {
  const RepeatSettings({
    required this.mode,
    this.ayahCount = 1,
    this.rangeStart,
    this.rangeEnd,
  });

  final RepeatMode mode;
  final int ayahCount;
  final int? rangeStart;
  final int? rangeEnd;

  RepeatSettings copyWith({
    RepeatMode? mode,
    int? ayahCount,
    int? rangeStart,
    int? rangeEnd,
  }) => RepeatSettings(
    mode: mode ?? this.mode,
    ayahCount: ayahCount ?? this.ayahCount,
    rangeStart: rangeStart ?? this.rangeStart,
    rangeEnd: rangeEnd ?? this.rangeEnd,
  );
}
