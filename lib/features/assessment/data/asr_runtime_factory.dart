// Runtime ASR dipilih per platform dari satu antarmuka AsrRuntime:
// Web memakai sherpa-onnx WASM, Android memakai sherpa-onnx Native FFI.
// Implementasi Web tidak pernah dipakai di Android, dan sebaliknya.
export 'asr_runtime_factory_native.dart'
    if (dart.library.js_interop) 'asr_runtime_factory_web.dart';
