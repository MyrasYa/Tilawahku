import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:tilawahku/features/assessment/data/recitation_recorder.dart';
import 'package:tilawahku/features/assessment/domain/recitation_audio.dart';

RecitationAudio _audioAtSeconds(double seconds) =>
    RecitationAudio(Float32List((seconds * 16000).round()));

RecordConfig _reported({int sampleRate = 16000, int numChannels = 1}) =>
    RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: numChannels,
    );

void main() {
  group('validateDeliveredFormat', () {
    test('accepts a mono 16 kHz recording that matches wall clock', () {
      expect(
        validateDeliveredFormat(
          audio: _audioAtSeconds(3),
          elapsedSeconds: 3,
          byteLength: 96000,
          reportedConfig: null,
        ),
        isNull,
      );
    });

    test('rejects empty or sub-byte recordings', () {
      for (final byteLength in [0, 1]) {
        expect(
          validateDeliveredFormat(
            audio: RecitationAudio(Float32List(0)),
            elapsedSeconds: 2,
            byteLength: byteLength,
            reportedConfig: null,
          )?.failure,
          RecitationCaptureFailure.emptyRecording,
          reason: 'byteLength: $byteLength',
        );
      }
    });

    test('rejects a platform that reports another sample rate', () {
      expect(
        validateDeliveredFormat(
          audio: _audioAtSeconds(3),
          elapsedSeconds: 3,
          byteLength: 96000,
          reportedConfig: _reported(sampleRate: 44100),
        )?.failure,
        RecitationCaptureFailure.unsupportedFormat,
      );
    });

    test('rejects a platform that reports more than one channel', () {
      expect(
        validateDeliveredFormat(
          audio: _audioAtSeconds(3),
          elapsedSeconds: 3,
          byteLength: 96000,
          reportedConfig: _reported(numChannels: 2),
        )?.failure,
        RecitationCaptureFailure.unsupportedFormat,
      );
    });

    test('rejects audio whose sample count implies a higher real rate', () {
      // 3 detik rekaman yang dikirim sebagai 44,1 kHz tetapi diberi label 16 kHz.
      expect(
        validateDeliveredFormat(
          audio: _audioAtSeconds(8.25),
          elapsedSeconds: 3,
          byteLength: 264000,
          reportedConfig: null,
        )?.failure,
        RecitationCaptureFailure.unsupportedFormat,
      );
    });

    test('flags a recording that lost most of its audio', () {
      expect(
        validateDeliveredFormat(
          audio: _audioAtSeconds(1),
          elapsedSeconds: 4,
          byteLength: 32000,
          reportedConfig: null,
        )?.failure,
        RecitationCaptureFailure.interrupted,
      );
    });

    test('skips the wall-clock check for very short captures', () {
      // Rasio 8 s sampel dalam 0,5 s dinding akan ditolak bila diperiksa,
      // tetapi bawah satu detik terlalu tidak presisi untuk dinilai.
      expect(
        validateDeliveredFormat(
          audio: _audioAtSeconds(8),
          elapsedSeconds: 0.5,
          byteLength: 256000,
          reportedConfig: null,
        ),
        isNull,
      );
    });
  });
}
