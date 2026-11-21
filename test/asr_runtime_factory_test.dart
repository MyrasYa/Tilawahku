import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/assessment/data/asr_runtime_factory.dart';

void main() {
  // Jalur native diuji di atas Dart VM; jalur Web hanya aktif bila test
  // dijalankan dengan --platform chrome, dan build web membuktikan adapternya
  // ikut ter-compile.
  test('runtime ASR dipilih sesuai platform', () {
    final runtime = createAsrRuntime();
    if (kIsWeb) {
      expect(runtime, isNotNull);
      expect('${runtime.runtimeType}', 'SherpaWasmAsrRuntime');
    } else {
      expect(runtime, isNull);
    }
  });
}
