import '../domain/recitation_audio.dart';

typedef AsrProgress = void Function(double? fraction, String message);

abstract interface class AsrRuntime {
  Future<void> prepare({AsrProgress? onProgress});

  Future<String> recognize(RecitationAudio audio);

  void dispose();
}

/// Kegagalan pengenalan yang pesannya sudah aman ditampilkan ke pengguna:
/// tidak ada kode status runtime yang ikut terbawa.
class AsrRecognitionException implements Exception {
  const AsrRecognitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Terjemahkan apa pun yang dilempar bindings ASR menjadi satu pesan pengguna.
///
/// Glue Emscripten `sherpa_onnx_web` melempar kode status mentah (sebuah angka,
/// misalnya `19328856`) ketika ONNX Runtime menolak input, jadi nilai yang
/// bukan teks tidak pernah dipakai apa adanya.
String describeAsrFailure(Object failure) {
  final text = failure is String || failure is Exception || failure is Error
      ? failure.toString().toLowerCase()
      : '';
  if (text.contains('invalid input shape') ||
      text.contains('non-zero status code')) {
    return 'Bagian bacaan ini tidak dapat diproses mesin. Silakan rekam ulang.';
  }
  if (text.contains('out of memory') ||
      text.contains('failed to allocate') ||
      text.contains('bad allocation')) {
    return 'Memori tidak cukup untuk menyelesaikan pengenalan. '
        'Tutup aplikasi lain lalu rekam ulang.';
  }
  return 'Pengenalan bacaan gagal. Silakan rekam ulang.';
}
