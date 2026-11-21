import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/domain/recitation_audio.dart';

void main() {
  group('RecitationAudio.fromPcm16', () {
    test('scales little-endian int16 to the -1..1 range', () {
      final audio = RecitationAudio.fromPcm16(
        Uint8List.fromList([0x00, 0x00, 0x00, 0x40, 0x00, 0x80, 0xff, 0x7f]),
      );

      expect(audio.samples.length, 4);
      expect(audio.samples[0], 0);
      expect(audio.samples[1], 0.5);
      expect(audio.samples[2], -1);
      expect(audio.samples[3], closeTo(0.99997, 1e-5));
      expect(audio.sampleRate, 16000);
      expect(audio.durationSeconds, 4 / 16000);
    });

    test('drops a trailing odd byte instead of reading past the buffer', () {
      final audio = RecitationAudio.fromPcm16(Uint8List.fromList([1, 2, 3]));

      expect(audio.samples.length, 1);
      expect(audio.durationSeconds, 1 / 16000);
    });

    test('yields no samples for empty input', () {
      expect(RecitationAudio.fromPcm16(Uint8List(0)).samples, isEmpty);
    });
  });

  group('lantai input engine', () {
    // Lantai terukur 1040 sampel; satu frame fbank = 160 sampel. Bukti:
    // asr-spike/probe_min_frames_analysis.json.
    test('ambang berupa kelipatan frame dan berada di atas lantai terukur', () {
      expect(asrMinimumSamples % 160, 0);
      expect(asrMinimumSamples, greaterThanOrEqualTo(1040));
      expect(asrMinimumSamples / 160, 10);
    });

    test('meetsAsrMinimum berubah tepat pada ambang', () {
      expect(
        RecitationAudio(Float32List(asrMinimumSamples - 1)).meetsAsrMinimum,
        isFalse,
      );
      expect(
        RecitationAudio(Float32List(asrMinimumSamples)).meetsAsrMinimum,
        isTrue,
      );
    });
  });
}
