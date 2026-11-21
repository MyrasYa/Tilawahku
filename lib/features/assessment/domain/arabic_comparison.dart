import 'dart:math' as math;

class WordChange {
  const WordChange(this.expected, this.recognized);

  final String expected;
  final String recognized;
}

class WordComparison {
  const WordComparison({
    required this.assessable,
    required this.matched,
    required this.changed,
    required this.missing,
    required this.extra,
    required this.referenceWordCount,
    required this.wordEdits,
  });

  final bool assessable;
  final List<String> matched;
  final List<WordChange> changed;
  final List<String> missing;
  final List<String> extra;
  final int referenceWordCount;
  final int wordEdits;

  double get matchPercent => referenceWordCount == 0
      ? 0
      : 100 * (1 - wordEdits / referenceWordCount).clamp(0, 1);
}

WordComparison compareArabicWords(
  String target,
  String transcript, {
  Map<String, String> spellingMap = const {},
}) {
  final expected = _words(target, spellingMap);
  final recognized = _words(transcript, spellingMap);
  // Dua kata pengenal dibutuhkan agar urutan bisa disejajarkan. Ayah dengan
  // satu kata kata referensi (42:2, 55:64) adalah pengecualian yang sah.
  final minimumRecognized = expected.length == 1 ? 1 : 2;
  if (expected.isEmpty || recognized.length < minimumRecognized) {
    return WordComparison(
      assessable: false,
      matched: const [],
      changed: const [],
      missing: expected,
      extra: recognized,
      referenceWordCount: expected.length,
      wordEdits: expected.length + recognized.length,
    );
  }

  final costs = List.generate(
    expected.length + 1,
    (_) => List<int>.filled(recognized.length + 1, 0),
  );
  for (var i = 0; i <= expected.length; i++) {
    costs[i][0] = i;
  }
  for (var j = 0; j <= recognized.length; j++) {
    costs[0][j] = j;
  }
  for (var i = 1; i <= expected.length; i++) {
    for (var j = 1; j <= recognized.length; j++) {
      final substitution = expected[i - 1] == recognized[j - 1] ? 0 : 1;
      costs[i][j] = math.min(
        costs[i - 1][j - 1] + substitution,
        math.min(costs[i - 1][j] + 1, costs[i][j - 1] + 1),
      );
    }
  }

  final matched = <String>[];
  final changed = <WordChange>[];
  final missing = <String>[];
  final extra = <String>[];
  var i = expected.length;
  var j = recognized.length;
  while (i > 0 || j > 0) {
    if (i > 0 &&
        j > 0 &&
        costs[i][j] ==
            costs[i - 1][j - 1] +
                (expected[i - 1] == recognized[j - 1] ? 0 : 1)) {
      if (expected[i - 1] == recognized[j - 1]) {
        matched.add(expected[i - 1]);
      } else {
        changed.add(WordChange(expected[i - 1], recognized[j - 1]));
      }
      i--;
      j--;
    } else if (i > 0 && costs[i][j] == costs[i - 1][j] + 1) {
      missing.add(expected[--i]);
    } else {
      extra.add(recognized[--j]);
    }
  }

  return WordComparison(
    assessable: true,
    matched: matched.reversed.toList(),
    changed: changed.reversed.toList(),
    missing: missing.reversed.toList(),
    extra: extra.reversed.toList(),
    referenceWordCount: expected.length,
    wordEdits: costs[expected.length][recognized.length],
  );
}

List<String> _words(String text, Map<String, String> spellingMap) {
  return normalizeArabic(text)
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .expand((word) => (spellingMap[word] ?? word).split(RegExp(r'\s+')))
      .where((word) => word.isNotEmpty)
      .toList();
}

String normalizeArabic(String text) {
  final output = StringBuffer();
  for (final rune in text.runes) {
    // Tatweel (U+0640) adalah pemanjangan huruf, bukan huruf: 460 ayat dalam
    // basis data memuatnya dan transkrip Imlaei tidak pernah mengirimkannya.
    if (rune == 0xfeff || rune == 0x0640 || _isArabicMark(rune)) continue;
    output.writeCharCode(rune == 0x0671 ? 0x0627 : rune);
  }
  return output.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool _isArabicMark(int rune) =>
    (rune >= 0x0610 && rune <= 0x061a) ||
    (rune >= 0x064b && rune <= 0x065f) ||
    rune == 0x0670 ||
    (rune >= 0x06d6 && rune <= 0x06ed);
