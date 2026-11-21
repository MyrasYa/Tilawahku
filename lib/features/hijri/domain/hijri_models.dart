/// Tanggal Hijri untuk satu hari, diekstrak dari respons AlAdhan.
class HijriCalendarDay {
  const HijriCalendarDay({
    required this.gregorianDate,
    required this.hijriDay,
    required this.hijriMonth,
    required this.hijriYear,
    required this.hijriMonthNameEn,
    required this.hijriMonthNameAr,
    required this.hijriMonthNameId,
    required this.weekdayEn,
    required this.weekdayAr,
    required this.isToday,
    this.events = const [],
  });

  /// Format yyyy-MM-dd menurut Gregorian.
  final String gregorianDate;

  /// Tanggal Hijri (1-30).
  final int hijriDay;

  /// Bulan Hijri (1-12).
  final int hijriMonth;

  /// Tahun Hijri.
  final int hijriYear;

  /// Nama bulan Hijri dalam bahasa Inggris.
  final String hijriMonthNameEn;

  /// Nama bulan Hijri dalam bahasa Arab.
  final String hijriMonthNameAr;

  /// Nama bulan Hijri dalam bahasa Indonesia.
  final String hijriMonthNameId;

  /// Nama hari dalam bahasa Inggris.
  final String weekdayEn;

  /// Nama hari dalam bahasa Arab.
  final String weekdayAr;

  /// Apakah hari ini adalah hari ini menurut Gregorian.
  final bool isToday;

  /// Event penting Islam untuk tanggal ini (jika ada).
  final List<IslamicEvent> events;

  /// Tanggal Hijri dengan penyesuaian pengguna.
  HijriCalendarDay withAdjustment(int adjustmentDays) {
    final adjusted = _adjustHijriDate(
      hijriDay: hijriDay,
      hijriMonth: hijriMonth,
      hijriYear: hijriYear,
      adjustmentDays: adjustmentDays,
    );
    return HijriCalendarDay(
      gregorianDate: gregorianDate,
      hijriDay: adjusted.day,
      hijriMonth: adjusted.month,
      hijriYear: adjusted.year,
      hijriMonthNameEn: hijriMonthNameEn,
      hijriMonthNameAr: hijriMonthNameAr,
      hijriMonthNameId: hijriMonthNameId,
      weekdayEn: weekdayEn,
      weekdayAr: weekdayAr,
      isToday: isToday,
      events: events,
    );
  }

  /// Tampilkan tanggal Hijri: "27 Ramadan 1446 H"
  String get displayLabel => '$hijriDay $hijriMonthNameId $hijriYear H';

  /// Tampilkan tanggal Arab: "رمضان 1446"
  String get arabicLabel => '$hijriMonthNameAr $hijriYear';
}

/// Satu bulan kalender Hijri.
class HijriCalendarMonth {
  const HijriCalendarMonth({
    required this.gregorianYear,
    required this.gregorianMonth,
    required this.days,
    required this.currentHijriDate,
  });

  /// Tahun Gregorian.
  final int gregorianYear;

  /// Bulan Gregorian (1-12).
  final int gregorianMonth;

  /// Semua hari dalam bulan ini.
  final List<HijriCalendarDay> days;

  /// Tanggal Hijri hari ini (tanpa penyesuaian).
  final HijriCalendarDay? currentHijriDate;

  /// Bulan kalender dengan penyesuaian pengguna.
  HijriCalendarMonth withAdjustment(int adjustmentDays) {
    return HijriCalendarMonth(
      gregorianYear: gregorianYear,
      gregorianMonth: gregorianMonth,
      days: days.map((day) => day.withAdjustment(adjustmentDays)).toList(),
      currentHijriDate: currentHijriDate?.withAdjustment(adjustmentDays),
    );
  }

  /// Cari hari berdasarkan tanggal Gregorian (yyyy-MM-dd).
  HijriCalendarDay? findByGregorianDate(String dateKey) {
    for (final day in days) {
      if (day.gregorianDate == dateKey) return day;
    }
    return null;
  }

  /// Hari pertama bulan ini.
  HijriCalendarDay? get firstDay => days.isNotEmpty ? days.first : null;

  /// Hari terakhir bulan ini.
  HijriCalendarDay? get lastDay => days.isNotEmpty ? days.last : null;
}

/// Event penting Islam.
class IslamicEvent {
  const IslamicEvent({
    required this.hijriDay,
    required this.hijriMonth,
    required this.nameId,
    required this.description,
  });

  /// Tanggal Hijri (1-30).
  final int hijriDay;

  /// Bulan Hijri (1-12).
  final int hijriMonth;

  /// Nama event dalam bahasa Indonesia.
  final String nameId;

  /// Penjelasan singkat dalam bahasa Indonesia.
  final String description;

  /// Kunci untuk mencari event dalam kalender: "MM-dd"
  String get hijriKey =>
      '${hijriMonth.toString().padLeft(2, '0')}-${hijriDay.toString().padLeft(2, '0')}';
}

/// Penyesuaian tanggal Hijri: -2 hingga +2 hari.
class HijriAdjustment {
  const HijriAdjustment([this.days = 0]);

  final int days;

  /// Batas penyesuaian: -2 hingga +2.
  static const int minDays = -2;
  static const int maxDays = 2;

  /// Validasi penyesuaian.
  bool get isValid => days >= minDays && days <= maxDays;

  /// Penyesuaian dengan validasi.
  HijriAdjustment validated() {
    if (!isValid) {
      return HijriAdjustment(days.clamp(minDays, maxDays));
    }
    return this;
  }

  /// Apakah ada penyesuaian aktif.
  bool get isActive => days != 0;

  /// Penyesuaian ke nilai baru dengan validasi.
  HijriAdjustment set(int value) {
    return HijriAdjustment(value.clamp(minDays, maxDays));
  }

  Map<String, dynamic> toMap() => {'hijri_adjustment_days': days};

  static HijriAdjustment fromMap(Map<String, dynamic> map) {
    final raw = map['hijri_adjustment_days'];
    final value = raw is int ? raw : 0;
    return HijriAdjustment(value.clamp(minDays, maxDays));
  }
}

/// Helper untuk penyesuaian tanggal Hijri.
({int day, int month, int year}) _adjustHijriDate({
  required int hijriDay,
  required int hijriMonth,
  required int hijriYear,
  required int adjustmentDays,
}) {
  var day = hijriDay + adjustmentDays;
  var month = hijriMonth;
  var year = hijriYear;

  // Normalisasi penyesuaian maju mundur antar bulan/tahun
  while (day < 1) {
    month--;
    if (month < 1) {
      month = 12;
      year--;
    }
    day += _daysInHijriMonth(month, year);
  }

  while (day > _daysInHijriMonth(month, year)) {
    day -= _daysInHijriMonth(month, year);
    month++;
    if (month > 12) {
      month = 1;
      year++;
    }
  }

  return (day: day, month: month, year: year);
}

/// Jumlah hari dalam bulan Hijri (perkiraan).
int _daysInHijriMonth(int month, int year) {
  // Bulan ganjil: 30 hari, bulan genap: 29 hari
  // Kecuali bulan genap dalam tahun kabisat: 30 hari
  // Tahun kabisat Hijri: habis dibagi 30
  if (month.isOdd) return 30;
  if (month.isEven) {
    final isLeap = year % 30 == 0;
    return isLeap ? 30 : 29;
  }
  return 30;
}

/// Event penting Islam yang ditentukan oleh tanggal Hijri.
/// Sumber: pengetahuan umum Islam, bukan dari API.
class IslamicEvents {
  IslamicEvents._();

  static final IslamicEvents instance = IslamicEvents._();

  final Map<String, IslamicEvent> _events = {
    '01-01': const IslamicEvent(
      hijriDay: 1,
      hijriMonth: 1,
      nameId: 'Tahun Baru Islam',
      description: 'Awal tahun Hijriah.',
    ),
    '10-01': const IslamicEvent(
      hijriDay: 10,
      hijriMonth: 1,
      nameId: 'Hari Asyura',
      description:
          'Hari ke-10 bulan Muharram, diperingati sebagai hari penting dalam Islam.',
    ),
    '12-03': const IslamicEvent(
      hijriDay: 12,
      hijriMonth: 3,
      nameId: 'Maulid Nabi',
      description: 'Hari kelahiran Nabi Muhammad SAW.',
    ),
    '27-07': const IslamicEvent(
      hijriDay: 27,
      hijriMonth: 7,
      nameId: 'Isra Mi\'raj',
      description:
          'Perjalanan malam Nabi Muhammad SAW dari Masjidil Haram ke Masjidil Aqsa.',
    ),
    '01-09': const IslamicEvent(
      hijriDay: 1,
      hijriMonth: 9,
      nameId: 'Awal Ramadan',
      description: 'Awal bulan puasa Ramadan.',
    ),
    '17-09': const IslamicEvent(
      hijriDay: 17,
      hijriMonth: 9,
      nameId: 'Nuzulul Quran',
      description: 'Turunnya Al-Quran pertama kali ke Nabi Muhammad SAW.',
    ),
    '01-10': const IslamicEvent(
      hijriDay: 1,
      hijriMonth: 10,
      nameId: 'Idul Fitri',
      description: 'Hari raya setelah menyelesaikan puasa Ramadan.',
    ),
    '10-12': const IslamicEvent(
      hijriDay: 10,
      hijriMonth: 12,
      nameId: 'Idul Adha',
      description:
          'Hari raya Qurban, memperingati Ibrahim AS bersedia mengorbankan putranya Ismail AS.',
    ),
  };

  /// Cari event berdasarkan kunci Hijri "MM-dd".
  IslamicEvent? findByHijriKey(String key) => _events[key];

  /// Semua event yang tersedia.
  List<IslamicEvent> get all => _events.values.toList(growable: false);
}
