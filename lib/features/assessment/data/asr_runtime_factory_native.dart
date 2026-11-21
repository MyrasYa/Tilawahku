import 'dart:io';

import 'asr_runtime.dart';
import 'sherpa_native_asr_runtime.dart';

// Sisi native: Android memakai sherpa-onnx Native FFI. Platform native lain
// (desktop) belum divalidasi untuk fitur ini, jadi tetap mengembalikan `null`
// dan UI menampilkan status "belum tersedia" alih-alih engine yang belum
// terbukti. Web tidak pernah sampai ke berkas ini — pemilihan jalur terjadi di
// `asr_runtime_factory.dart`.
AsrRuntime? createAsrRuntime() =>
    Platform.isAndroid ? SherpaNativeAsrRuntime() : null;
