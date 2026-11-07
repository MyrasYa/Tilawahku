import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/player/presentation/playback_speed_dialog.dart';

void main() {
  testWidgets('speed dialog applies a selected playback speed', (tester) async {
    final appliedSpeeds = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackSpeedDialog(
            initialSpeed: 1,
            onChanged: (speed) async => appliedSpeeds.add(speed),
            onError: (error) => fail('$error'),
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0.5);
    expect(slider.max, 2);
    expect(slider.divisions, 6);

    slider.onChanged!(1.5);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(1.5);
    await tester.pumpAndSettle();

    expect(appliedSpeeds, [1.5]);
    expect(find.text('1.5×'), findsOneWidget);
  });

  testWidgets('speed dialog restores the previous value on failure', (
    tester,
  ) async {
    final reportedErrors = <Object>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackSpeedDialog(
            initialSpeed: 1,
            onChanged: (_) async => throw StateError('audio unavailable'),
            onError: reportedErrors.add,
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1.5);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(1.5);
    await tester.pumpAndSettle();

    expect(reportedErrors, hasLength(1));
    expect(find.text('1×'), findsOneWidget);
  });
}
