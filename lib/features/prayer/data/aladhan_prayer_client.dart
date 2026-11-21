import 'package:dio/dio.dart';

import '../../hijri/domain/hijri_models.dart';
import '../domain/prayer_method.dart';
import '../domain/prayer_models.dart';

/// Kegagalan sumber data jadwal sholat dengan pesan yang siap ditampilkan.
///
/// Nilai mentah (kode status, body error) hanya layak masuk log; pengguna
/// menerima apa yang harus mereka lakukan.
class PrayerDataSourceException implements Exception {
  const PrayerDataSourceException(this.kind, this.message);

  final PrayerDataFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

enum PrayerDataFailureKind { offline, timeout, server, rejected, malformed }

/// Kontrak sumber jadwal harian.
///
/// Dipisahkan dari `AladhanPrayerClient` supaya `PrayerRepository` dapat diuji
/// dengan sumber tiruan: yang diuji adalah kebijakan cache dan fallback, bukan
/// HTTP.
abstract interface class PrayerDaySource {
  Future<PrayerDaySchedule> fetchDay({
    required String dateKey,
    required WorshipLocation location,
    required PrayerMethod method,
    required AsrMadhab asrMadhab,
  });
}

/// Klien AlAdhan API v1.
///
/// Sumber: `https://api.aladhan.com/v1/timings/{tanggal}` — endpoint publik yang
/// tidak memerlukan API key. Bentuk respons diverifikasi pada 2026-11-20 dengan
/// respons nyata yang disimpan sebagai fixture di
/// `research/Tilawahku-asr-poc/prd-master/evidence/`, dan parser di bawah diuji
/// terhadap fixture tersebut (`test/aladhan_prayer_client_test.dart`).
///
/// `iso8601=true` diminta supaya setiap waktu kembali sebagai stamp beroffset
/// (mis. `2026-11-20T04:03:00+07:00`). Dengan offset eksplisit, instan absolut
/// untuk hitung mundur dapat dihitung tanpa basis data zona waktu perangkat,
/// dan jam tangan lokal lokasi tetap tampil seperti yang dilaporkan server.
class AladhanPrayerClient implements PrayerDaySource {
  AladhanPrayerClient({Dio? dio, Uri? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      _baseUrl = baseUrl ?? Uri.parse('https://api.aladhan.com/v1');

  static const host = 'api.aladhan.com';
  static const termsOfUse = 'https://aladhan.com/term-of-use';

  final Dio _dio;
  final Uri _baseUrl;

  @override
  Future<PrayerDaySchedule> fetchDay({
    required String dateKey,
    required WorshipLocation location,
    required PrayerMethod method,
    required AsrMadhab asrMadhab,
  }) async {
    final path = _datePath(dateKey);
    // Nilai query harus String: `Uri.replace` menolak angka (double/int) dan
    // gagal dengan TypeError saat runtime, jadi format di sini, bukan andalkan
    // konversi implisit.
    final uri = _baseUrl.replace(
      path: '/v1/timings/$path',
      queryParameters: {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'method': '${method.aladhanId}',
        'school': '${asrMadhab.aladhanSchool}',
        'iso8601': 'true',
      },
    );
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(uri.toString());
    } on DioException catch (error) {
      throw _mapTransportError(error);
    }
    final payload = response.data;
    if (payload == null) {
      throw const PrayerDataSourceException(
        PrayerDataFailureKind.malformed,
        'Jadwal sholat tidak dapat dibaca: respons kosong.',
      );
    }
    return parse(payload, requestedDateKey: dateKey, method: method);
  }

  /// Format tanggal jalur API: `DD-MM-YYYY`.
  static String _datePath(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) {
      throw FormatException('Kunci tanggal harus yyyy-MM-dd, dapat $dateKey');
    }
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  static PrayerDataSourceException _mapTransportError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const PrayerDataSourceException(
        PrayerDataFailureKind.timeout,
        'Jadwal sholat tidak dapat diambil tepat waktu. Periksa koneksi lalu '
        'coba lagi.',
      ),
      DioExceptionType.connectionError => const PrayerDataSourceException(
        PrayerDataFailureKind.offline,
        'Perangkat sedang luring. Jadwal yang tersimpan dipakai bila ada.',
      ),
      DioExceptionType.badResponse => PrayerDataSourceException(
        PrayerDataFailureKind.server,
        'Layanan jadwal membalas ${error.response?.statusCode}. '
        'Coba lagi beberapa saat.',
      ),
      _ => const PrayerDataSourceException(
        PrayerDataFailureKind.server,
        'Layanan jadwal sholat sedang tidak dapat dihubungi.',
      ),
    };
  }

  /// Parse murni agar teruji tanpa jaringan.
  ///
  /// Yang divalidasi: `code`/`status`, keberadaan kelima waktu sholat, offset
  /// zona waktu, dan konsistensi metode yang diminta dengan metode yang dipakai
  /// server. Kalau server memakai metode lain, hasil ditolak — menampilkan
  /// jadwal dengan label metode yang salah lebih berbahaya daripada kegagalan
  /// yang jelas.
  static PrayerDaySchedule parse(
    Map<String, dynamic> payload, {
    required String requestedDateKey,
    required PrayerMethod method,
  }) {
    final code = payload['code'];
    final status = payload['status'];
    if (code is! num || code.toInt() != 200 || status != 'OK') {
      throw PrayerDataSourceException(
        PrayerDataFailureKind.rejected,
        'Layanan jadwal menolak permintaan (status $status).',
      );
    }
    final data = payload['data'];
    if (data is! Map) {
      throw const PrayerDataSourceException(
        PrayerDataFailureKind.malformed,
        'Jadwal sholat tidak dapat dibaca: struktur respons tidak dikenal.',
      );
    }
    final timings = data['timings'];
    final meta = data['meta'];
    if (timings is! Map || meta is! Map) {
      throw const PrayerDataSourceException(
        PrayerDataFailureKind.malformed,
        'Jadwal sholat tidak dapat dibaca: waktu atau metadata hilang.',
      );
    }

    final timezoneId = meta['timezone'] as String?;
    if (timezoneId == null || timezoneId.isEmpty) {
      throw const PrayerDataSourceException(
        PrayerDataFailureKind.malformed,
        'Jadwal sholat tidak dapat dibaca: zona waktu tidak dikirim.',
      );
    }

    final metaMethod = meta['method'];
    if (metaMethod is Map) {
      final usedId = (metaMethod['id'] as num?)?.toInt();
      if (usedId != null && usedId != method.aladhanId) {
        throw PrayerDataSourceException(
          PrayerDataFailureKind.malformed,
          'Layanan memakai metode $usedId, bukan ${method.aladhanId} '
          '(${method.name}) yang dipilih.',
        );
      }
    }

    final events = <PrayerEvent>[];
    Duration? offsetForDay;
    for (final kind in PrayerKind.values) {
      final raw = timings[kind.apiField];
      if (raw is! String) continue;
      final parsed = parseInstant(raw);
      if (parsed == null) {
        throw PrayerDataSourceException(
          PrayerDataFailureKind.malformed,
          'Waktu ${kind.labelId} tidak dapat dibaca: $raw',
        );
      }
      final (instant, offset) = parsed;
      offsetForDay ??= offset;
      events.add(
        PrayerEvent(kind: kind, instant: instant, locationOffset: offset),
      );
    }
    for (final kind in PrayerKind.values) {
      if (!kind.isSalat) continue;
      if (!events.any((event) => event.kind == kind)) {
        throw PrayerDataSourceException(
          PrayerDataFailureKind.malformed,
          'Waktu ${kind.labelId} tidak dikirim layanan.',
        );
      }
    }

    final date = data['date'];
    return PrayerDaySchedule(
      dateKey: requestedDateKey,
      timezoneId: timezoneId,
      locationOffset: offsetForDay ?? Duration.zero,
      methodId: method.aladhanId,
      asrMadhab: _schoolOf(meta),
      events: events,
      source: ScheduleSource.live,
      hijri: date is Map ? _hijri(date['hijri']) : null,
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  /// `2026-11-20T04:03:00+07:00` -> (instan UTC, offset +07:00).
  ///
  /// Dipakai juga oleh cache agar nilai yang disimpan dan yang dibaca kembali
  /// melewati satu parser yang sama.
  static (DateTime, Duration)? parseInstant(String raw) {
    final match = RegExp(r'([+-])(\d{2}):?(\d{2})$').firstMatch(raw);
    final instant = DateTime.tryParse(raw);
    if (instant == null) return null;
    if (match == null) return (instant.toUtc(), Duration.zero);
    final sign = match.group(1) == '-' ? -1 : 1;
    final offset = Duration(
      hours: int.parse(match.group(2)!),
      minutes: int.parse(match.group(3)!),
    );
    return (instant.toUtc(), Duration(minutes: sign * offset.inMinutes));
  }

  static AsrMadhab _schoolOf(Map<dynamic, dynamic> meta) {
    final school = meta['school'];
    if (school is String && school.toUpperCase() == 'HANAFI') {
      return AsrMadhab.hanafi;
    }
    return AsrMadhab.standard;
  }

  static HijriDate? _hijri(Object? raw) {
    if (raw is! Map) return null;
    final day = int.tryParse('${raw['day']}');
    final year = int.tryParse('${raw['year']}');
    final month = raw['month'];
    final monthNumber =
        (month is Map ? int.tryParse('${month['number']}') : null) ??
        int.tryParse('${raw['month']}');
    if (day == null || year == null || monthNumber == null) return null;
    return HijriDate(
      day: day,
      month: monthNumber,
      year: year,
      monthNameEn: month is Map ? '${month['en'] ?? ''}' : '',
      monthNameAr: month is Map ? '${month['ar'] ?? ''}' : '',
      weekdayEn: raw['weekday'] is Map
          ? '${(raw['weekday'] as Map)['en'] ?? ''}'
          : '',
      method: raw['method'] is String ? '${raw['method']}' : null,
      holidays: raw['holidays'] is List
          ? (raw['holidays'] as List).map((e) => '$e').toList()
          : const [],
    );
  }

  /// Parse respons kalender bulanan dari AlAdhan.
  static HijriCalendarMonth parseCalendar(
    Map<String, dynamic> payload,
    int gregorianYear,
    int gregorianMonth,
  ) {
    return _parseCalendar(payload, gregorianYear, gregorianMonth);
  }

  /// Parse respons kalender bulanan dari AlAdhan (internal).
  static HijriCalendarMonth _parseCalendar(
    Map<String, dynamic> payload,
    int gregorianYear,
    int gregorianMonth,
  ) {
    final code = payload['code'];
    final status = payload['status'];
    if (code is! num || code.toInt() != 200 || status != 'OK') {
      throw PrayerDataSourceException(
        PrayerDataFailureKind.rejected,
        'Layanan kalender menolak permintaan (status $status).',
      );
    }
    final data = payload['data'];
    if (data is! List) {
      throw const PrayerDataSourceException(
        PrayerDataFailureKind.malformed,
        'Kalender Hijri tidak dapat dibaca: struktur respons tidak dikenal.',
      );
    }

    final List<HijriCalendarDay> days = [];
    HijriCalendarDay? currentHijriDate;
    final now = DateTime.now();

    for (final dayData in data) {
      if (dayData is! Map) continue;
      final date = dayData['date'];
      if (date is! Map) continue;

      final gregorian = date['gregorian'];
      if (gregorian is! Map) continue;

      final gregorianDay = gregorian['day'];
      final gregorianMonthNum = gregorian['month'] is Map
          ? (gregorian['month'] as Map)['number']
          : null;
      final gregorianYearNum = gregorian['year'];

      if (gregorianDay is! int ||
          gregorianMonthNum is! int ||
          gregorianYearNum is! int) {
        continue;
      }

      final hijri = date['hijri'];
      if (hijri is! Map) continue;

      final hijriDay = int.tryParse('${hijri['day']}');
      final hijriMonth = hijri['month'] is Map
          ? int.tryParse('${(hijri['month'] as Map)['number']}')
          : null;
      final hijriYear = int.tryParse('${hijri['year']}');

      if (hijriDay == null || hijriMonth == null || hijriYear == null) {
        continue;
      }

      final monthNameEn = hijri['month'] is Map
          ? '${(hijri['month'] as Map)['en'] ?? ''}'
          : '';
      final monthNameAr = hijri['month'] is Map
          ? '${(hijri['month'] as Map)['ar'] ?? ''}'
          : '';
      final weekdayEn = hijri['weekday'] is Map
          ? '${(hijri['weekday'] as Map)['en'] ?? ''}'
          : '';
      final weekdayAr = hijri['weekday'] is Map
          ? '${(hijri['weekday'] as Map)['ar'] ?? ''}'
          : '';

      // Map nama bulan Inggris ke Indonesia
      final monthNameId = _mapMonthNameId(monthNameEn);

      final dateKey =
          '$gregorianYearNum-${gregorianMonthNum.toString().padLeft(2, '0')}-${gregorianDay.toString().padLeft(2, '0')}';
      final isToday = dateKey == _dateKeyFor(now);

      final day = HijriCalendarDay(
        gregorianDate: dateKey,
        hijriDay: hijriDay,
        hijriMonth: hijriMonth,
        hijriYear: hijriYear,
        hijriMonthNameEn: monthNameEn,
        hijriMonthNameAr: monthNameAr,
        hijriMonthNameId: monthNameId,
        weekdayEn: weekdayEn,
        weekdayAr: weekdayAr,
        isToday: isToday,
        events: _mapEvents(hijriDay, hijriMonth),
      );

      days.add(day);

      if (isToday) {
        currentHijriDate = day;
      }
    }

    return HijriCalendarMonth(
      gregorianYear: gregorianYear,
      gregorianMonth: gregorianMonth,
      days: days,
      currentHijriDate: currentHijriDate,
    );
  }

  /// Map nama bulan Hijri dari Inggris ke Indonesia.
  static String _mapMonthNameId(String enName) {
    final mapping = {
      'Muharram': 'Muharram',
      'Safar': 'Safar',
      'Rabiul Awal': 'Rabiul Awal',
      'Rabiul Akhir': 'Rabiul Akhir',
      'Jumādá al-ūlá': 'Jumadil Ula',
      'Jumādá al-ākhirah': 'Jumadil Akhir',
      'Rajab': 'Rajab',
      "Sya'ban": 'Sya\'ban',
      'Ramadan': 'Ramadan',
      'Shawwal': 'Syawal',
      "Dzulqa'dah": 'Dzulqa\'dah',
      'Dzulhijjah': 'Dzulhijjah',
    };
    return mapping[enName] ?? enName;
  }

  /// Map tanggal Hijri ke event Islam penting.
  static List<IslamicEvent> _mapEvents(int hijriDay, int hijriMonth) {
    final key =
        '${hijriMonth.toString().padLeft(2, '0')}-${hijriDay.toString().padLeft(2, '0')}';
    final event = IslamicEvents.instance.findByHijriKey(key);
    return event != null ? [event] : const [];
  }

  /// Format tanggal yyyy-MM-dd.
  static String _dateKeyFor(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void close() => _dio.close(force: true);
}
