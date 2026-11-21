import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/player/domain/sleep_timer_controller.dart';

void main() {
  test('resetting timer replaces the deadline and expires only once', () async {
    var now = DateTime(2026, 11, 8);
    var expirationCount = 0;
    final controller = SleepTimerController(
      now: () => now,
      onExpire: () async => expirationCount++,
      onError: (error, stackTrace) => fail('$error'),
    );
    addTearDown(controller.dispose);

    controller.start(const Duration(minutes: 5));
    now = now.add(const Duration(minutes: 2));
    controller.start(const Duration(minutes: 10));
    expect(controller.deadline, DateTime(2026, 11, 8, 0, 12));

    now = DateTime(2026, 11, 8, 0, 5);
    controller.checkDeadline();
    await Future<void>.delayed(Duration.zero);
    expect(expirationCount, 0);
    expect(controller.remaining, const Duration(minutes: 7));

    now = DateTime(2026, 11, 8, 0, 12);
    controller.checkDeadline();
    controller.checkDeadline();
    await Future<void>.delayed(Duration.zero);
    expect(expirationCount, 1);
    expect(controller.deadline, isNull);
  });

  test('cancel clears countdown and prevents expiration', () async {
    var now = DateTime(2026, 11, 8);
    var expirationCount = 0;
    final controller = SleepTimerController(
      now: () => now,
      onExpire: () async => expirationCount++,
      onError: (error, stackTrace) => fail('$error'),
    );
    addTearDown(controller.dispose);

    controller.start(const Duration(minutes: 15));
    controller.cancel();
    now = now.add(const Duration(hours: 1));
    controller.checkDeadline();
    await Future<void>.delayed(Duration.zero);

    expect(controller.remaining, isNull);
    expect(expirationCount, 0);
  });

  test(
    'resume deadline check expires immediately when deadline has passed',
    () async {
      var now = DateTime(2026, 11, 8);
      var paused = false;
      final controller = SleepTimerController(
        now: () => now,
        onExpire: () async => paused = true,
        onError: (error, stackTrace) => fail('$error'),
      );
      addTearDown(controller.dispose);

      controller.start(const Duration(minutes: 5));
      now = now.add(const Duration(minutes: 8));
      controller.checkDeadline();
      await Future<void>.delayed(Duration.zero);

      expect(paused, isTrue);
      expect(controller.remaining, isNull);
    },
  );
}
