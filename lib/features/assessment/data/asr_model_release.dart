/// Satu berkas yang dibutuhkan runtime ASR Web di dalam filesystem WASM.
class AsrModelFile {
  const AsrModelFile({
    required this.name,
    required this.byteLength,
    required this.sha256Hex,
  });

  final String name;
  final int byteLength;
  final String sha256Hex;
}

/// Identitas rilis model ASR Web: lokasi relatif, ukuran, dan SHA-256 yang
/// diharapkan. Berkas disajikan dari `web/asr/` (ikut tersalin ke akar hasil
/// build Web) dan sengaja TIDAK dideklarasikan sebagai asset Flutter, sehingga
/// 36 MB model tidak masuk `flutter_assets` dan tidak diunduh sebelum pengguna
/// memulai penilaian.
///
/// Sumber model: `Abdou/quran-asr-small` (int8 Zipformer CTC, MIT, hak cipta
/// 2026 Abdou) — berkas yang sama dengan PoC; identitas silang diverifikasi
/// lewat MD5 `7bb5013a682842553f532bc6194cd953` pada
/// `asr-spike/model.int8.onnx`, `flutter-asr-poc/assets/model/`, dan
/// `android-asr-poc/assets/model/`. URL unduhan asal tidak terdokumentasi di
/// PoC; SHA-256 di bawah inilah yang menjadi acuan integritas.
class AsrModelRelease {
  const AsrModelRelease({
    required this.id,
    required this.version,
    required this.directory,
    required this.model,
    required this.tokens,
  });

  final String id;
  final String version;

  /// Direktori relatif terhadap `baseURI` dokumen.
  final String directory;

  /// Bobot ONNX Zipformer CTC dan daftar token yang dipakai konfigurasi engine.
  final AsrModelFile model;
  final AsrModelFile tokens;

  List<AsrModelFile> get files => [model, tokens];

  int get totalBytes => files.fold(0, (sum, file) => sum + file.byteLength);

  /// Cache Storage dinamai per rilis sehingga model versi baru tidak pernah
  /// membaca cache versi lama.
  String get cacheName => 'tilawahku-asr-$id-$version';
}

const asrWebModelRelease = AsrModelRelease(
  id: 'quran-asr-small-int8',
  version: 'int8-88f9df29',
  directory: 'asr',
  model: AsrModelFile(
    name: 'model.int8.onnx',
    byteLength: 36081762,
    sha256Hex:
        '88f9df290d57b8890275d79187b77515aeeb12626a42bc76cbd0f8bfcaff00f0',
  ),
  tokens: AsrModelFile(
    name: 'tokens.txt',
    byteLength: 180,
    sha256Hex:
        '75b53814499cee84a07c7b7a318524d30bcaf84273c0f8b28a04176023e8c74f',
  ),
);
