import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/repeat/domain/repeat_settings.dart';

void main() {
  const globalNumbers = [1, 2, 3, 4];
  const surahNumbers = [1, 1, 2, 2];
  const juzNumbers = [1, 1, 1, 2];

  test('ayah repeat counts total plays of the active ayah', () {
    final plan = RepeatPlaybackPlan.create(
      settings: const RepeatSettings(mode: RepeatMode.ayah, repeatCount: 4),
      globalNumbers: globalNumbers,
      surahNumbers: surahNumbers,
      juzNumbers: juzNumbers,
      currentIndex: 2,
    );

    expect(plan?.startIndex, 2);
    expect(plan?.endIndex, 2);
    expect(plan?.repeatCount, 4);
  });

  test(
    'finite repeat continues after its final pass when queue has a tail',
    () {
      final plan = RepeatPlaybackPlan.create(
        settings: const RepeatSettings(
          mode: RepeatMode.range,
          repeatCount: 2,
          rangeStart: 2,
          rangeEnd: 3,
        ),
        globalNumbers: globalNumbers,
        surahNumbers: surahNumbers,
        juzNumbers: juzNumbers,
        currentIndex: 2,
      )!;

      expect(
        plan.actionAfterCompletedPass(completedPasses: 1, queueLength: 4),
        RepeatBoundaryAction.repeatScope,
      );
      expect(
        plan.actionAfterCompletedPass(completedPasses: 2, queueLength: 4),
        RepeatBoundaryAction.continueQueue,
      );
    },
  );

  test('finite repeat stops after its final pass at queue end', () {
    final plan = RepeatPlaybackPlan.create(
      settings: const RepeatSettings(mode: RepeatMode.ayah, repeatCount: 1),
      globalNumbers: globalNumbers,
      surahNumbers: surahNumbers,
      juzNumbers: juzNumbers,
      currentIndex: 3,
    )!;

    expect(
      plan.actionAfterCompletedPass(completedPasses: 1, queueLength: 4),
      RepeatBoundaryAction.stop,
    );
  });

  test('range repeat uses inclusive endpoints and contains active ayah', () {
    final plan = RepeatPlaybackPlan.create(
      settings: const RepeatSettings(
        mode: RepeatMode.range,
        repeatCount: 2,
        rangeStart: 2,
        rangeEnd: 3,
      ),
      globalNumbers: globalNumbers,
      surahNumbers: surahNumbers,
      juzNumbers: juzNumbers,
      currentIndex: 2,
    );

    expect(plan?.startIndex, 1);
    expect(plan?.endIndex, 2);
  });

  test('surah repeat is bounded to the active surah', () {
    final plan = RepeatPlaybackPlan.create(
      settings: const RepeatSettings(mode: RepeatMode.surah),
      globalNumbers: globalNumbers,
      surahNumbers: surahNumbers,
      juzNumbers: juzNumbers,
      currentIndex: 2,
    );

    expect(plan?.startIndex, 2);
    expect(plan?.endIndex, 3);
  });

  test('juz repeat includes its ayahs across a surah boundary', () {
    final plan = RepeatPlaybackPlan.create(
      settings: const RepeatSettings(mode: RepeatMode.juz),
      globalNumbers: globalNumbers,
      surahNumbers: surahNumbers,
      juzNumbers: juzNumbers,
      currentIndex: 1,
    );

    expect(plan?.startIndex, 0);
    expect(plan?.endIndex, 2);
    expect(surahNumbers[plan!.startIndex], isNot(surahNumbers[plan.endIndex]));
  });

  test('range repeat rejects a scope that excludes the active ayah', () {
    expect(
      () => RepeatPlaybackPlan.create(
        settings: const RepeatSettings(
          mode: RepeatMode.range,
          rangeStart: 1,
          rangeEnd: 2,
        ),
        globalNumbers: globalNumbers,
        surahNumbers: surahNumbers,
        juzNumbers: juzNumbers,
        currentIndex: 2,
      ),
      throwsStateError,
    );
  });

  test('range repeat rejects missing ayahs in the loaded queue', () {
    expect(
      () => RepeatPlaybackPlan.create(
        settings: const RepeatSettings(
          mode: RepeatMode.range,
          rangeStart: 1,
          rangeEnd: 4,
        ),
        globalNumbers: [1, 2, 4],
        surahNumbers: [1, 1, 1],
        juzNumbers: [1, 1, 1],
        currentIndex: 1,
      ),
      throwsStateError,
    );
  });
}
