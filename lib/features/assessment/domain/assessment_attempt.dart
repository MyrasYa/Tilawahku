import 'dart:convert';

import 'arabic_comparison.dart';

class AssessmentAttempt {
  const AssessmentAttempt({
    required this.transcript,
    required this.comparison,
    required this.audioSeconds,
    this.note,
  });

  final String transcript;
  final WordComparison comparison;
  final double audioSeconds;

  /// Penjelasan tambahan saat bacaan sengaja tidak dikirim ke mesin, misalnya
  /// rekaman lebih pendek dari minimum yang bisa diproses model.
  final String? note;

  bool get isScorable => comparison.assessable;

  Map<String, dynamic> toJson() => {
    'transcript': transcript,
    'audio_seconds': audioSeconds,
    'match_percent': comparison.matchPercent,
    'word_edits': comparison.wordEdits,
    'reference_word_count': comparison.referenceWordCount,
    'assessable': comparison.assessable,
    'matched': comparison.matched,
    'missing': comparison.missing,
    'extra': comparison.extra,
    if (note != null) 'note': note,
  };

  String toJsonString() => jsonEncode(toJson());
}
