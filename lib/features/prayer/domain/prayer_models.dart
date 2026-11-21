import 'prayer_method.dart';

/// Enam waktu yang dikirim AlAdhan; `sunrise` dibawa karena ia membatasi
/// jendela Subuh, tetapi bukan waktu sholat.
enum PrayerKind {
  fajr('Subuh', 'Fajr', true),
  sunrise('Syuruk', 'Sunrise', false),
  dhuhr('Zuhur', 'Dhuhr', true),
  asr('Asar', 'Asr', true),
  maghrib('Magrib', 'Maghrib', true),
  isha('Isya', 'Isha', true);

  const PrayerKind(this.labelId, this.apiField, this.isSalat);

  final String labelId;
  final String apiField;
  final bool isSalat;

  static PrayerKind? fromApiField(String field) {
    for (final kind in values) {
      if (kind.apiField.toLowerCase() == field.toLowerCase()) return kind;
    }
    return null;
  }
}

/// Asal sebuah jadwal: langsung dari server, atau dibaca dari cache lokal.
enum ScheduleSource {
  live('dari server'),
  cache('dari cache'),
  stale('cache basi');

  const ScheduleSource(this.labelId);

  final String labelId;
}

/// Satu waktu sholat.
///
/// `instant` adalah titik waktu mutlak (UTC) hasil parsing stamp ISO 8601
/// beroffset dari API, jadi hitung mundur tetap benar walau zona waktu perangkat
/// berbeda dari zona waktu lokasi. `wallClock` adalah jam tangan lokal lokasi
/// seperti yang ditampilkan jadwal.
class PrayerEvent {
  const PrayerEvent({
    required this.kind,
    required this.instant,
    required this.locationOffset,
  });

  final PrayerKind kind;
  final DateTime instant;
  final Duration locationOffset;

  DateTime get locationDateTime => instant.toUtc().add(locationOffset);

  String get wallClock {
    final local = locationDateTime;
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  PrayerEvent shift(Duration delta) => PrayerEvent(
    kind: kind,
    instant: instant.add(delta),
    locationOffset: locationOffset,
  );

  /// Batas tampilan untuk jendela adzan: waktu hasil penyesuaian manual.
  PrayerEvent withAdjustment(int? minutes) => minutes == null || minutes == 0
      ? this
      : shift(Duration(minutes: minutes));

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// Jadwal satu hari pada satu lokasi dan satu metode perhitungan.
class PrayerDaySchedule {
  const PrayerDaySchedule({
    required this.dateKey,
    required this.timezoneId,
    required this.locationOffset,
    required this.methodId,
    required this.asrMadhab,
    required this.events,
    required this.source,
    this.hijri,
    this.fetchedAt,
  });

  /// `yyyy-MM-dd` menurut zona waktu lokasi.
  final String dateKey;
  final String timezoneId;
  final Duration locationOffset;
  final int methodId;
  final AsrMadhab asrMadhab;
  final List<PrayerEvent> events;
  final ScheduleSource source;
  final HijriDate? hijri;
  final DateTime? fetchedAt;

  /// Waktu sholat lima waktu, terurut.
  List<PrayerEvent> get salatEvents =>
      events.where((event) => event.kind.isSalat).toList(growable: false);

  PrayerEvent? eventFor(PrayerKind kind) {
    for (final event in events) {
      if (event.kind == kind) return event;
    }
    return null;
  }

  bool covers(PrayerKind kind) => eventFor(kind) != null;

  /// Jadwal dengan penyesuaian menit per waktu diterapkan.
  ///
  /// Penyesuaian terjadi di sisi aplikasi (bukan parameter API) supaya nilai
  /// yang tersimpan di cache tetap identik dengan keluaran server, dan
  /// perubahan penyesuaian tidak memaksa unduhan ulang.
  PrayerDaySchedule withAdjustments(PrayerAdjustments adjustments) {
    if (adjustments.isEmpty) return this;
    return PrayerDaySchedule(
      dateKey: dateKey,
      timezoneId: timezoneId,
      locationOffset: locationOffset,
      methodId: methodId,
      asrMadhab: asrMadhab,
      events: [
        for (final event in events)
          event.withAdjustment(adjustments.minutesFor(event.kind)),
      ],
      source: source,
      hijri: hijri,
      fetchedAt: fetchedAt,
    );
  }
}

/// Koreksi menit manual per waktu sholat; hanya waktu sholat yang bisa
/// disesuaikan, dan rentangnya dibatasi agar tidak menggeser hari.
class PrayerAdjustments {
  const PrayerAdjustments([this._minutes = const {}]);

  static const int maxMinutes = 30;

  final Map<PrayerKind, int> _minutes;

  int? minutesFor(PrayerKind kind) => _minutes[kind];

  bool get isEmpty => _minutes.values.every((value) => value == 0);

  Map<PrayerKind, int> get entries => Map.unmodifiable(_minutes);

  PrayerAdjustments set(PrayerKind kind, int minutes) {
    if (!kind.isSalat) {
      throw ArgumentError.value(
        kind,
        'kind',
        'Hanya waktu sholat yang bisa disesuaikan.',
      );
    }
    if (minutes.abs() > maxMinutes) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        'Penyesuaian dibatasi +/-$maxMinutes menit.',
      );
    }
    final next = Map<PrayerKind, int>.from(_minutes)..[kind] = minutes;
    return PrayerAdjustments(Map.unmodifiable(next));
  }

  static PrayerAdjustments fromMap(Map<String, dynamic> map) {
    final minutes = <PrayerKind, int>{};
    for (final entry in map.entries) {
      PrayerKind? kind;
      for (final value in PrayerKind.values) {
        if (value.name == entry.key) {
          kind = value;
          break;
        }
      }
      // Kunci tak dikenal dilewati, bukan dipetakan ke waktu pertama: nilai
      // rusak dari versi app lama tidak boleh mengubah Subuh pengguna.
      if (kind == null || !kind.isSalat) continue;
      final raw = entry.value;
      if (raw is! num) continue;
      final value = raw.toInt().clamp(-maxMinutes, maxMinutes);
      if (value != 0) minutes[kind] = value;
    }
    return PrayerAdjustments(Map.unmodifiable(minutes));
  }

  Map<String, dynamic> toMap() => {
    for (final entry in _minutes.entries)
      if (entry.value != 0) entry.key.name: entry.value,
  };
}

class HijriDate {
  const HijriDate({
    required this.day,
    required this.month,
    required this.year,
    required this.monthNameEn,
    required this.monthNameAr,
    required this.weekdayEn,
    this.method,
    this.holidays = const [],
  });

  final int day;
  final int month;
  final int year;
  final String monthNameEn;
  final String monthNameAr;
  final String weekdayEn;

  /// Nama metode penentuan hijriah dari server (mis. `HJCoSA`). Ditampilkan
  /// supaya pengguna tahu ini perhitungan, bukan keputusan rukyat resmi.
  final String? method;

  /// Hari besar yang dilaporkan server untuk tanggal tersebut.
  final List<String> holidays;

  String get labelId => '$day ${_bulanId(month)} $year H';

  static const List<String> _bulan = [
    'Muharram',
    'Safar',
    "Rabiul Awal",
    'Rabiul Akhir',
    'Jumadil Ula',
    'Jumadil Akhir',
    'Rajab',
    "Sya'ban",
    'Ramadan',
    'Syawal',
    "Dzulqa'dah",
    'Dzulhijjah',
  ];

  static String _bulanId(int month) =>
      (month >= 1 && month <= 12) ? _bulan[month - 1] : 'bulan $month';

  /// Nama bulan Arab rawan karakter unik, jadi ditampilkan apa adanya.
  String get arabicLabel => '$monthNameAr $year';
}

/// Lokasi yang dipakai untuk menghitung jadwal.
class WorshipLocation {
  const WorshipLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.timezoneId,
    this.country,
  });

  final String name;
  final double latitude;
  final double longitude;
  final LocationSource source;
  final String? timezoneId;
  final String? country;

  /// Kunci cache stabil: koordinat dibulatkan ke ~1 km (4 desimal desimal
  /// derajat ≈ 11 m; 3 desimal ≈ 111 m). Pembulatan ini membuat perangkat yang
  /// bergetar di dalam kota tidak menghasilkan entri cache baru tiap menit.
  String get cacheKey =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  Map<String, dynamic> toMap() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'source': source.name,
    'timezone_id': timezoneId,
    'country': country,
  };

  static WorshipLocation fromMap(Map<String, dynamic> map) => WorshipLocation(
    name: map['name'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    source: LocationSource.values.firstWhere(
      (value) => value.name == map['source'],
      orElse: () => LocationSource.manual,
    ),
    timezoneId: map['timezone_id'] as String?,
    country: map['country'] as String?,
  );

  static bool coordinateInRange(double latitude, double longitude) =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

enum LocationSource {
  gps('GPS'),
  manual('manual'),
  saved('tersimpan');

  const LocationSource(this.labelId);

  final String labelId;
}

/// Pengaturan penilaian waktu sholat yang disimpan permanen.
class PrayerSettings {
  const PrayerSettings({
    required this.method,
    required this.asrMadhab,
    required this.adjustments,
    this.location,
    this.remindersEnabled = false,
    this.reminderLeadMinutes = 10,
    this.reminderKinds = const {},
  });

  final PrayerMethod method;
  final AsrMadhab asrMadhab;
  final PrayerAdjustments adjustments;
  final WorshipLocation? location;

  /// Pengingat hanya efektif pada platform dengan penjadwal sistem; status
  /// platform dilaporkan terpisah oleh `PrayerReminderStatus`.
  final bool remindersEnabled;
  final int reminderLeadMinutes;

  /// Waktu sholat yang diingatkan. Himpunan kosong berarti semua waktu,
  /// dipakai bersama `remindersEnabled` agar pengguna lama tidak tiba-tiba
  /// kehilangan pengingat yang sudah menyala.
  final Set<PrayerKind> reminderKinds;

  static const int maxLeadMinutes = 60;

  PrayerSettings copyWith({
    PrayerMethod? method,
    AsrMadhab? asrMadhab,
    PrayerAdjustments? adjustments,
    WorshipLocation? location,
    bool? remindersEnabled,
    int? reminderLeadMinutes,
    Set<PrayerKind>? reminderKinds,
  }) => PrayerSettings(
    method: method ?? this.method,
    asrMadhab: asrMadhab ?? this.asrMadhab,
    adjustments: adjustments ?? this.adjustments,
    location: location ?? this.location,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
    reminderKinds: reminderKinds ?? this.reminderKinds,
  );

  bool get hasValidLocation {
    final place = location;
    if (place == null) return false;
    return WorshipLocation.coordinateInRange(place.latitude, place.longitude);
  }
}

/// Kunci cache jadwal: tanggal + lokasi + metode + madhab. Tanpa keempatnya,
/// pergantian metode akan menampilkan jadwal metode lama.
String scheduleCacheKey({
  required String dateKey,
  required WorshipLocation location,
  required PrayerMethod method,
  required AsrMadhab asrMadhab,
}) => '$dateKey|${location.cacheKey}|${method.aladhanId}|${asrMadhab.name}';

/// Batas umur cache. Jadwal hari ini selalu diminta ulang bila jaringan ada;
/// nilai ini dipakai untuk hari-hari sekitar (mis. jadwal besok).
const Duration prayerCacheTtl = Duration(hours: 12);
