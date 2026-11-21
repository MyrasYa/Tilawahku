import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/asr_runtime.dart';
import 'package:tilawahku/features/assessment/data/recitation_recorder.dart';
import 'package:tilawahku/features/assessment/domain/recitation_audio.dart';
import 'package:tilawahku/features/assessment/presentation/recitation_assessment_controller.dart';

final _twoSeconds = RecitationAudio(Float32List(32000));
const _basmalah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
const _basmalahSpoken = 'بسم الله الرحمن الرحيم';

void main() {
  RecitationAssessmentController build({
    AsrRuntime? runtime,
    _FakeCapture? capture,
    Map<String, String> spellingMap = const {},
  }) => RecitationAssessmentController(
    runtime: runtime,
    createCapture: () => capture ?? _FakeCapture(),
    loadSpellingMap: () async => spellingMap,
  );

  group('RecitationAssessmentController', () {
    test(
      'is unavailable and never opens the microphone without a runtime',
      () async {
        var created = 0;
        final controller = RecitationAssessmentController(
          runtime: null,
          createCapture: () {
            created++;
            return _FakeCapture();
          },
        );

        expect(controller.phase, AssessmentPhase.unavailable);
        expect(controller.canRecord, isFalse);
        await controller.startRecording();
        await controller.stopAndScore(_basmalah);
        expect(controller.phase, AssessmentPhase.unavailable);
        expect(controller.attempt, isNull);
        expect(created, 0);
        controller.dispose();
      },
    );

    test('scores a recording with the shared comparison engine', () async {
      final runtime = _FakeRuntime(_basmalahSpoken);
      final controller = build(runtime: runtime);

      await controller.startRecording();
      expect(controller.phase, AssessmentPhase.recording);
      await controller.stopAndScore(_basmalah);

      expect(controller.phase, AssessmentPhase.scored);
      final attempt = controller.attempt!;
      expect(attempt.comparison.matched, hasLength(4));
      expect(attempt.comparison.wordEdits, 0);
      expect(attempt.isScorable, isTrue);
      expect(attempt.audioSeconds, 2);
      expect(runtime.recognized, hasLength(1));
      controller.dispose();
    });

    test('prepares the runtime once and forwards progress', () async {
      final runtime = _FakeRuntime(_basmalahSpoken)
        ..prepareGate = Completer<void>();
      final controller = build(runtime: runtime);

      final firstStart = controller.startRecording();
      await _yield();
      expect(controller.phase, AssessmentPhase.preparing);
      expect(controller.progressMessage, '50 % · mengunduh model');
      runtime.prepareGate!.complete();
      await firstStart;
      await controller.stopAndScore(_basmalah);

      await controller.startRecording();
      await controller.stopAndScore(_basmalah);

      expect(runtime.prepareCalls, 1);
      expect(runtime.recognized, hasLength(2));
      controller.dispose();
    });

    test('ignores a second start while recording', () async {
      final capture = _FakeCapture();
      final controller = build(
        runtime: _FakeRuntime(_basmalahSpoken),
        capture: capture,
      );

      await controller.startRecording();
      await controller.startRecording();

      expect(capture.startCalls, 1);
      expect(controller.phase, AssessmentPhase.recording);
      controller.dispose();
    });

    test('keeps a denied microphone as a failure, not a result', () async {
      final controller = build(
        runtime: _FakeRuntime(_basmalahSpoken),
        capture: _FakeCapture(
          startError: RecitationCaptureException(
            RecitationCaptureFailure.permissionDenied,
            'Izin mikrofon belum diberikan sehingga bacaan tidak dapat dinilai.',
          ),
        ),
      );

      await controller.startRecording();

      expect(controller.phase, AssessmentPhase.failed);
      expect(controller.attempt, isNull);
      expect(controller.message, contains('Izin mikrofon'));
      expect(controller.canRecord, isTrue);
      controller.dispose();
    });

    test(
      'keeps a failed recording separate from an unscorable result',
      () async {
        final failureController = build(
          runtime: _FakeRuntime(_basmalahSpoken),
          capture: _FakeCapture(
            stopError: RecitationCaptureException(
              RecitationCaptureFailure.emptyRecording,
              'Tidak ada audio yang terekam.',
            ),
          ),
        );
        await failureController.startRecording();
        await failureController.stopAndScore(_basmalah);
        expect(failureController.phase, AssessmentPhase.failed);
        expect(failureController.attempt, isNull);
        failureController.dispose();

        final unscorableController = build(
          runtime: _FakeRuntime('الله'),
          capture: _FakeCapture(),
        );
        await unscorableController.startRecording();
        await unscorableController.stopAndScore(_basmalah);
        expect(unscorableController.phase, AssessmentPhase.scored);
        expect(unscorableController.attempt!.isScorable, isFalse);
        expect(unscorableController.message, isNull);
        unscorableController.dispose();
      },
    );

    test('switching mode stops an active recording', () async {
      final capture = _FakeCapture();
      final controller = build(
        runtime: _FakeRuntime(_basmalahSpoken),
        capture: capture,
      );
      await controller.startRecording();
      expect(controller.isRecording, isTrue);

      await controller.setMode(AssessmentMode.setoran);

      expect(controller.mode, AssessmentMode.setoran);
      expect(controller.phase, AssessmentPhase.idle);
      expect(controller.isRecording, isFalse);
      expect(capture.cancelCalls, 1);
      controller.dispose();
    });

    test('hides the target text only while setoran is working', () async {
      final capture = _FakeCapture();
      final controller = build(
        runtime: _FakeRuntime(_basmalahSpoken),
        capture: capture,
      );

      await controller.startRecording();
      expect(controller.hidesTargetText, isFalse);
      await controller.stopAndScore(_basmalah);
      expect(controller.hidesTargetText, isFalse);

      await controller.setMode(AssessmentMode.setoran);
      expect(controller.hidesTargetText, isFalse);
      await controller.startRecording();
      expect(controller.hidesTargetText, isTrue);

      capture.stopGate = Completer<void>();
      final scoring = controller.stopAndScore(_basmalah);
      await _yield();
      expect(controller.phase, AssessmentPhase.processing);
      expect(controller.hidesTargetText, isTrue);
      capture.stopGate!.complete();
      await scoring;
      expect(controller.hidesTargetText, isFalse);
      controller.dispose();
    });

    test('discarding clears the previous result', () async {
      final controller = build(runtime: _FakeRuntime(_basmalahSpoken));
      await controller.startRecording();
      await controller.stopAndScore(_basmalah);
      expect(controller.attempt, isNotNull);

      await controller.discardRecording();

      expect(controller.attempt, isNull);
      expect(controller.phase, AssessmentPhase.idle);
      controller.dispose();
    });

    test(
      'discarding while the model downloads never opens the microphone',
      () async {
        final runtime = _FakeRuntime(_basmalahSpoken)
          ..prepareGate = Completer<void>();
        final capture = _FakeCapture();
        final controller = build(runtime: runtime, capture: capture);

        final starting = controller.startRecording();
        await _yield();
        expect(controller.phase, AssessmentPhase.preparing);

        await controller.discardRecording();
        runtime.prepareGate!.complete();
        await starting;

        expect(capture.startCalls, 0);
        expect(controller.phase, AssessmentPhase.idle);
        expect(controller.attempt, isNull);
        controller.dispose();
      },
    );

    test(
      'leaving the page while the model downloads never opens the microphone',
      () async {
        final runtime = _FakeRuntime(_basmalahSpoken)
          ..prepareGate = Completer<void>();
        final capture = _FakeCapture();
        final controller = build(runtime: runtime, capture: capture);

        final starting = controller.startRecording();
        await _yield();
        controller.dispose();
        runtime.prepareGate!.complete();
        await starting;

        expect(capture.startCalls, 0);
        expect(runtime.disposeCalls, 1);
      },
    );

    test('closes a microphone that finishes opening after the recording was '
        'cancelled', () async {
      final capture = _FakeCapture()..startGate = Completer<void>();
      final controller = build(
        runtime: _FakeRuntime(_basmalahSpoken),
        capture: capture,
      );

      final starting = controller.startRecording();
      await _yield();
      await controller.discardRecording();
      capture.startGate!.complete();
      await starting;

      // Satu pembatalan datang sebelum `start()` selesai, satu lagi
      // menutup mikrofon yang baru terbuka setelahnya.
      expect(capture.startCalls, 1);
      expect(capture.cancelCalls, 2);
      expect(controller.phase, AssessmentPhase.idle);
      expect(controller.isRecording, isFalse);
      controller.dispose();
    });

    test(
      'discarding during inference never publishes a stale result',
      () async {
        final runtime = _FakeRuntime(_basmalahSpoken)
          ..recognizeGate = Completer<void>();
        final capture = _FakeCapture();
        final controller = build(runtime: runtime, capture: capture);
        await controller.startRecording();

        final scoring = controller.stopAndScore(_basmalah);
        await _yield();
        expect(controller.phase, AssessmentPhase.processing);

        await controller.discardRecording();
        await controller.startRecording();
        runtime.recognizeGate!.complete();
        await scoring;

        expect(controller.attempt, isNull);
        expect(controller.phase, AssessmentPhase.recording);
        expect(controller.isRecording, isTrue);
        controller.dispose();
      },
    );

    test('dropping the page during inference publishes nothing', () async {
      final runtime = _FakeRuntime(_basmalahSpoken)
        ..recognizeGate = Completer<void>();
      final controller = build(runtime: runtime);
      await controller.startRecording();

      final scoring = controller.stopAndScore(_basmalah);
      await _yield();
      controller.dispose();
      runtime.recognizeGate!.complete();
      await scoring;

      expect(controller.attempt, isNull);
      expect(runtime.disposeCalls, 1);
    });

    test('audio di bawah lantai engine tidak pernah dikenali dan divonis '
        'Unscorable', () async {
      final runtime = _FakeRuntime(_basmalahSpoken);
      final controller = build(
        runtime: runtime,
        capture: _FakeCapture(
          audio: RecitationAudio(Float32List(asrMinimumSamples - 1)),
        ),
      );

      await controller.startRecording();
      await controller.stopAndScore(_basmalah);

      expect(
        runtime.recognized,
        isEmpty,
        reason:
            'engine tidak boleh menerima '
            'audio yang pasti ditolak ONNX Runtime',
      );
      expect(controller.phase, AssessmentPhase.scored);
      final attempt = controller.attempt!;
      expect(attempt.isScorable, isFalse);
      expect(attempt.comparison.matchPercent, 0);
      expect(attempt.transcript, isEmpty);
      expect(attempt.note, contains('terlalu singkat'));
      expect(controller.message, isNull);
      expect(controller.canRecord, isTrue);
      controller.dispose();
    });

    test('audio tepat di lantai engine tetap dikirim ke runtime', () async {
      final runtime = _FakeRuntime(_basmalahSpoken);
      final controller = build(
        runtime: runtime,
        capture: _FakeCapture(
          audio: RecitationAudio(Float32List(asrMinimumSamples)),
        ),
      );

      await controller.startRecording();
      await controller.stopAndScore(_basmalah);

      expect(runtime.recognized, hasLength(1));
      expect(controller.attempt!.note, isNull);
      expect(controller.attempt!.isScorable, isTrue);
      controller.dispose();
    });

    test(
      'kegagalan pengenalan memakai pesan terpetakan tanpa kode runtime',
      () async {
        final runtime = _FakeRuntime(_basmalahSpoken)
          ..recognizeError = const AsrRecognitionException(
            'Pengenalan bacaan gagal. Silakan rekam ulang.',
          );
        final controller = build(runtime: runtime);

        await controller.startRecording();
        await controller.stopAndScore(_basmalah);

        expect(controller.phase, AssessmentPhase.failed);
        expect(controller.attempt, isNull);
        expect(
          controller.message,
          'Pengenalan bacaan gagal. Silakan rekam ulang.',
        );
        controller.dispose();
      },
    );

    test(
      'nilai mentah dari platform tidak muncul sebagai angka telanjang',
      () async {
        final runtime = _FakeRuntime(_basmalahSpoken)
          ..recognizeError = 19328856;
        final controller = build(runtime: runtime);

        await controller.startRecording();
        await controller.stopAndScore(_basmalah);

        expect(controller.phase, AssessmentPhase.failed);
        expect(controller.message, isNot(contains('19328856')));
        controller.dispose();
      },
    );

    test('releasing the controller frees microphone and runtime', () async {
      final capture = _FakeCapture();
      final runtime = _FakeRuntime(_basmalahSpoken);
      final controller = build(runtime: runtime, capture: capture);
      await controller.startRecording();

      controller.dispose();
      await controller.released;

      expect(capture.disposeCalls, 1);
      expect(runtime.disposeCalls, 1);
    });

    test('uses the spelling map from the shared engine', () async {
      final controller = build(
        runtime: _FakeRuntime('يا ايها الذين'),
        spellingMap: const {'يايها': 'يا ايها'},
      );

      await controller.startRecording();
      await controller.stopAndScore('يٰٓاَيُّهَا الَّذينَ');

      expect(controller.attempt!.comparison.wordEdits, 0);
      expect(controller.attempt!.comparison.matched, hasLength(3));
      controller.dispose();
    });
  });
}

Future<void> _yield() => Future<void>.delayed(Duration.zero);

class _FakeRuntime implements AsrRuntime {
  _FakeRuntime(this.transcript);

  final String transcript;
  final recognized = <RecitationAudio>[];
  Completer<void>? prepareGate;
  Completer<void>? recognizeGate;
  Object? recognizeError;
  int prepareCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> prepare({AsrProgress? onProgress}) async {
    prepareCalls++;
    onProgress?.call(0.5, 'mengunduh model');
    await prepareGate?.future;
  }

  @override
  Future<String> recognize(RecitationAudio audio) async {
    await recognizeGate?.future;
    recognized.add(audio);
    final error = recognizeError;
    if (error != null) throw error;
    return transcript;
  }

  @override
  void dispose() => disposeCalls++;
}

class _FakeCapture implements RecitationCapture {
  _FakeCapture({this.startError, this.stopError, RecitationAudio? audio})
    : audio = audio ?? _twoSeconds;

  final Object? startError;
  final Object? stopError;
  final RecitationAudio audio;

  Completer<void>? startGate;
  Completer<void>? stopGate;
  int startCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> start() async {
    startCalls++;
    await startGate?.future;
    final error = startError;
    if (error != null) throw error;
  }

  @override
  Future<RecitationAudio> stop() async {
    await stopGate?.future;
    final error = stopError;
    if (error != null) throw error;
    return audio;
  }

  @override
  Future<void> cancel() async => cancelCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}
