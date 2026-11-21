import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/asr_runtime.dart';

/// Pemetaan kegagalan engine pengenalan. Angka status yang dilempar glue
/// Emscripten (mis. `19328856`) dan bentuk tensor internal tidak boleh sampai
/// ke layar; pengguna hanya menerima penyebab yang bisa dia tindak lanjuti.
void main() {
  group('describeAsrFailure', () {
    test('kode status mentah tidak pernah ikut ditampilkan', () {
      final message = describeAsrFailure(19328856);

      expect(message, isNot(contains('19328856')));
      expect(message, contains('rekam ulang'));
    });

    test('string numerik juga diperlakukan sebagai kode internal', () {
      expect(describeAsrFailure('19328856'), isNot(contains('19328856')));
    });

    test('penolakan bentuk input ONNX dipetakan ke penyebabnya', () {
      final message = describeAsrFailure(
        'Non-zero status code returned while running Conv node. '
        'Status Message: Invalid input shape: {2,39}',
      );

      expect(message, contains('tidak dapat diproses mesin'));
      expect(message, isNot(contains('{2,39}')));
      expect(message, isNot(contains('Conv')));
    });

    test('kegagalan memori dipisahkan dari kegagalan umum', () {
      expect(
        describeAsrFailure('Failed to allocate memory for 36081762 bytes'),
        contains('Memori tidak cukup'),
      );
    });

    test('error yang tidak dikenal jatuh ke pesan umum yang aman', () {
      expect(
        describeAsrFailure(StateError('Bad state: something internal')),
        'Pengenalan bacaan gagal. Silakan rekam ulang.',
      );
    });
  });

  test('AsrRecognitionException membawa pesan apa adanya', () {
    const error = AsrRecognitionException('Pengenalan bacaan gagal.');

    expect(error.toString(), 'Pengenalan bacaan gagal.');
  });
}
