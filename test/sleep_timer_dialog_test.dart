import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/player/presentation/sleep_timer_dialog.dart';

void main() {
  testWidgets('sleep timer offers all presets and an active cancel action', (
    tester,
  ) async {
    final remainingController = StreamController<Duration?>.broadcast();
    addTearDown(remainingController.close);
    var cancelled = false;
    final startedDurations = <Duration>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SleepTimerDialog(
            initialRemaining: const Duration(minutes: 4, seconds: 59),
            remainingStream: remainingController.stream,
            onStart: startedDurations.add,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    for (final minutes in [5, 10, 15, 30, 45, 60]) {
      expect(find.text('$minutes menit'), findsOneWidget);
    }
    expect(find.text('Jeda otomatis dalam 04:59'), findsOneWidget);

    await tester.tap(find.text('10 menit'));
    expect(startedDurations, [const Duration(minutes: 10)]);
    await tester.tap(find.text('Batalkan timer'));
    expect(cancelled, isTrue);
  });
}
