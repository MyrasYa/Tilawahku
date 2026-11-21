import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/assessment_lexicon.dart';
import 'package:tilawahku/features/assessment/domain/arabic_comparison.dart';

class _Sample {
  const _Sample({
    required this.label,
    required this.target,
    required this.transcript,
    required this.matched,
    required this.changed,
    required this.missing,
    required this.extra,
    required this.matchPercent,
  });

  final String label;
  final String target;
  final String transcript;
  final int matched;
  final int changed;
  final int missing;
  final int extra;
  final double matchPercent;
}

/// Angka pembanding adalah hasil runtime ASR sebenarnya pada PoC:
/// research/Tilawahku-asr-poc/android-asr-poc/evidence/native-windows-x64.json
/// (sherpa-onnx 2.0.1, ONNX Runtime 1.28.2, provider cpu). Yang diuji di sini
/// hanya mesin perbandingan kata, jadi transkrip disalin apa adanya.
const _samples = <_Sample>[
  _Sample(
    label: 'Surah 1:1',
    target: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
    transcript: 'بسم الله الرحمن الرحيم',
    matched: 4,
    changed: 0,
    missing: 0,
    extra: 0,
    matchPercent: 100,
  ),
  _Sample(
    label: 'Surah 1:2',
    target: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
    transcript: 'الحمد لله رب العلمين',
    matched: 4,
    changed: 0,
    missing: 0,
    extra: 0,
    matchPercent: 100,
  ),
  _Sample(
    label: 'Surah 1:3',
    target: 'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
    transcript: 'الرحمن الرحيم',
    matched: 2,
    changed: 0,
    missing: 0,
    extra: 0,
    matchPercent: 100,
  ),
  _Sample(
    label: 'Surah 2:248',
    target:
        'وَقَالَ لَهُمْ نَبِيُّهُمْ إِنَّ ءَايَةَ مُلْكِهِۦٓ أَن يَأْتِيَكُمُ ٱلتَّابُوتُ فِيهِ سَكِينَةٌۭ مِّن رَّبِّكُمْ وَبَقِيَّةٌۭ مِّمَّا تَرَكَ ءَالُ مُوسَىٰ وَءَالُ هَٰرُونَ تَحْمِلُهُ ٱلْمَلَٰٓئِكَةُ ۚ إِنَّ فِى ذَٰلِكَ لَءَايَةًۭ لَّكُمْ إِن كُنتُم مُّؤْمِنِينَ',
    transcript:
        'وقال لهم نبيهم ان ءايه ملكه ان ياتيكم التابوت فيه سكينه من ربكم وبقيه مما ترك ءال موسي وءال هرون تحمله المليكه ان في ذلك لايه لكم ان كنتم مومنين',
    matched: 17,
    changed: 13,
    missing: 0,
    extra: 0,
    matchPercent: 56.7,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ported comparison engine', () {
    test('reproduces the PoC word-diff counts', () async {
      final spellingMap = await const AssessmentLexicon().load();

      for (final sample in _samples) {
        final result = compareArabicWords(
          sample.target,
          sample.transcript,
          spellingMap: spellingMap,
        );

        expect(result.assessable, isTrue, reason: sample.label);
        expect(result.matched.length, sample.matched, reason: sample.label);
        expect(result.changed.length, sample.changed, reason: sample.label);
        expect(result.missing.length, sample.missing, reason: sample.label);
        expect(result.extra.length, sample.extra, reason: sample.label);
        expect(
          result.matchPercent,
          closeTo(sample.matchPercent, 0.05),
          reason: sample.label,
        );
      }
    });
  });
}
