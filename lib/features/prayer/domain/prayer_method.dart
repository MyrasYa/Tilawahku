/// Metode perhitungan waktu sholat.
///
/// Setiap entri disalin dari respons `meta.method` AlAdhan API v1 yang diambil
/// pada 2026-11-20 dan disimpan di
/// `research/Tilawahku-asr-poc/prd-master/evidence/aladhan-method-params.json`.
/// Sudut tidak dikarang: `fajrAngle`/`ishaAngle` adalah nilai yang dilaporkan
/// server untuk id tersebut, dan `ishaAfterMaghrib` dipakai bila server
/// melaporkan aturan menit (bukan sudut).
class PrayerMethod {
  const PrayerMethod({
    required this.aladhanId,
    required this.name,
    required this.fajrAngle,
    this.ishaAngle,
    this.ishaAfterMaghrib,
  });

  final int aladhanId;
  final String name;
  final double fajrAngle;
  final double? ishaAngle;
  final int? ishaAfterMaghrib;

  /// Aturan Isya dalam satu baris, dipakai UI supaya pengguna tahu apa yang
  /// berubah saat metode diganti.
  String get ishaRule => ishaAngle != null
      ? 'sudut ${_angle(ishaAngle!)}'
      : '$ishaAfterMaghrib menit setelah Magrib';

  String get angleSummary =>
      'Subuh ${_angle(fajrAngle)} · Isya $ishaRule';

  static String _angle(double value) =>
      value == value.roundToDouble()
      ? '${value.toStringAsFixed(0)}°'
      : '${value.toStringAsFixed(1)}°';

  static PrayerMethod byId(int id) =>
      values.firstWhere((method) => method.aladhanId == id);

  static const PrayerMethod kemenag = PrayerMethod(
    aladhanId: 20,
    name: 'Kementerian Agama Republik Indonesia',
    fajrAngle: 20,
    ishaAngle: 18,
  );

  /// Metode bawaan aplikasi: konteks pengguna utama adalah Indonesia.
  static const PrayerMethod defaultMethod = kemenag;

  /// Hanya metode yang namanya dan sudutnya terverifikasi dari respons API.
  /// Id lain tetap bisa dipakai lewat `aladhanId`, tetapi tidak ditawarkan di
  /// UI supaya tidak ada label yang belum terbukti.
  static const List<PrayerMethod> values = [
    kemenag,
    PrayerMethod(
      aladhanId: 11,
      name: 'Majlis Ugama Islam Singapura, Singapore',
      fajrAngle: 20,
      ishaAngle: 18,
    ),
    PrayerMethod(
      aladhanId: 17,
      name: 'Jabatan Kemajuan Islam Malaysia (JAKIM)',
      fajrAngle: 20,
      ishaAngle: 18,
    ),
    PrayerMethod(
      aladhanId: 3,
      name: 'Muslim World League',
      fajrAngle: 18,
      ishaAngle: 17,
    ),
    PrayerMethod(
      aladhanId: 1,
      name: 'University of Islamic Sciences, Karachi',
      fajrAngle: 18,
      ishaAngle: 18,
    ),
    PrayerMethod(
      aladhanId: 2,
      name: 'Islamic Society of North America (ISNA)',
      fajrAngle: 15,
      ishaAngle: 15,
    ),
    PrayerMethod(
      aladhanId: 5,
      name: 'Egyptian General Authority of Survey',
      fajrAngle: 19.5,
      ishaAngle: 17.5,
    ),
    PrayerMethod(
      aladhanId: 4,
      name: 'Umm Al-Qura University, Makkah',
      fajrAngle: 18.5,
      ishaAfterMaghrib: 90,
    ),
  ];
}

/// Madhab untuk waktu Asar. Nilai `aladhanSchool` dan pergeseran hasilnya
/// diverifikasi pada 2026-11-20: `school=0` -> `meta.school STANDARD`
/// Asar 15:02, `school=1` -> `meta.school HANAFI` Asar 16:05 untuk Jakarta.
enum AsrMadhab {
  standard('Syafi\'i / Maliki / Hanbali', 0),
  hanafi('Hanafi', 1);

  const AsrMadhab(this.labelId, this.aladhanSchool);

  final String labelId;
  final int aladhanSchool;

  static AsrMadhab fromName(String? name) => values.firstWhere(
    (madhab) => madhab.name == name?.toLowerCase(),
    orElse: () => standard,
  );
}
