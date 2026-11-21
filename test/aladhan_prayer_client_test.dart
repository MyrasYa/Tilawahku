import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/prayer/data/aladhan_prayer_client.dart';
import 'package:tilawahku/features/prayer/domain/prayer_method.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';

/// Parser diuji terhadap respons AlAdhan yang benar-benar diambil pada
/// 2026-11-20 (bukan contoh yang dikarang), sehingga bentuk field, offset,
/// dan metadata yang diperiksa adalah apa yang dikirim server.
void main() {
  final jakartaStandard = _fixture('timings-jakarta-2026-11-20.json');
  final jakartaHanafi = _fixture('timings-jakarta-hanafi-2026-11-20.json');
  final kemenag = PrayerMethod.byId(20);
  final jakarta = WorshipLocation(
    name: 'Jakarta',
    latitude: -6.175,
    longitude: 106.827,
    source: LocationSource.saved,
    timezoneId: 'Asia/Jakarta',
  );

  group('fetchDay membangun permintaan', () {
    test(
      'memakai jalur DD-MM-YYYY dan parameter metode/school/iso8601',
      () async {
        final adapter = _CaptureAdapter(jakartaStandard);
        final client = AladhanPrayerClient(dio: _dio(adapter));
        addTearDown(client.close);

        await client.fetchDay(
          dateKey: '2026-11-20',
          location: jakarta,
          method: kemenag,
          asrMadhab: AsrMadhab.hanafi,
        );

        final options = adapter.last!;
        expect(options.uri.path, '/v1/timings/20-11-2026');
        expect(options.uri.host, 'api.aladhan.com');
        expect(options.uri.queryParameters['latitude'], '-6.175');
        expect(options.uri.queryParameters['longitude'], '106.827');
        expect(options.uri.queryParameters['method'], '20');
        expect(options.uri.queryParameters['school'], '1');
        expect(options.uri.queryParameters['iso8601'], 'true');
      },
    );

    test(
      'menolak tanggal dengan format salah sebelum menyentuh jaringan',
      () async {
        final adapter = _CaptureAdapter(jakartaStandard);
        final client = AladhanPrayerClient(dio: _dio(adapter));
        addTearDown(client.close);

        expect(
          () => client.fetchDay(
            dateKey: '2026-11',
            location: jakarta,
            method: kemenag,
            asrMadhab: AsrMadhab.standard,
          ),
          throwsA(isA<FormatException>()),
        );
        expect(adapter.calls, 0);
      },
    );

    test(
      'mengubah kegagalan transport menjadi alasan yang bisa ditampilkan',
      () async {
        final client = AladhanPrayerClient(
          dio: _dio(
            _ThrowingAdapter(
              DioException(
                requestOptions: RequestOptions(path: '/v1/timings/20-11-2026'),
                type: DioExceptionType.connectionError,
              ),
            ),
          ),
        );
        addTearDown(client.close);

        await expectLater(
          client.fetchDay(
            dateKey: '2026-11-20',
            location: jakarta,
            method: kemenag,
            asrMadhab: AsrMadhab.standard,
          ),
          throwsA(
            isA<PrayerDataSourceException>()
                .having((e) => e.kind, 'kind', PrayerDataFailureKind.offline)
                .having((e) => e.message, 'message', contains('luring')),
          ),
        );
      },
    );
  });

  group('parse respons nyata Jakarta 2026-11-20 (metode 20)', () {
    final schedule = AladhanPrayerClient.parse(
      jakartaStandard,
      requestedDateKey: '2026-11-20',
      method: kemenag,
    );

    test(
      'memakai kunci tanggal yang diminta, bukan yang dilaporkan server',
      () {
        expect(schedule.dateKey, '2026-11-20');
        expect(schedule.timezoneId, 'Asia/Jakarta');
        expect(schedule.locationOffset, const Duration(hours: 7));
        expect(schedule.methodId, 20);
        expect(schedule.asrMadhab, AsrMadhab.standard);
        expect(schedule.source, ScheduleSource.live);
        expect(schedule.fetchedAt, isNotNull);
      },
    );

    test(
      'hanya enam waktu yang dikenal yang dibawa, lima di antaranya sholat',
      () {
        expect(schedule.events, hasLength(PrayerKind.values.length));
        expect(schedule.salatEvents, hasLength(5));
        expect(schedule.covers(PrayerKind.sunrise), isTrue);
        expect(schedule.eventFor(PrayerKind.sunrise)!.kind.isSalat, isFalse);
        expect(PrayerKind.fromApiField('Midnight'), isNull);
        expect(PrayerKind.fromApiField('imsak'), isNull);
      },
    );

    test('instan absolut dan jam tangan lokal konsisten dengan offset +07', () {
      expect(schedule.eventFor(PrayerKind.fajr)!.wallClock, '04:03');
      expect(
        schedule.eventFor(PrayerKind.fajr)!.instant,
        DateTime.utc(2026, 11, 19, 21, 3),
      );
      expect(
        schedule.eventFor(PrayerKind.dhuhr)!.instant,
        DateTime.utc(2026, 11, 20, 4, 38),
      );
      expect(schedule.eventFor(PrayerKind.asr)!.wallClock, '15:02');
      expect(schedule.eventFor(PrayerKind.maghrib)!.wallClock, '17:51');
      expect(schedule.eventFor(PrayerKind.isha)!.wallClock, '19:05');
      expect(schedule.salatEvents.first.kind, PrayerKind.fajr);
      expect(schedule.salatEvents.last.kind, PrayerKind.isha);
    });

    test('tanggal hijriah dan metodenya terbawa apa adanya', () {
      final hijri = schedule.hijri!;
      expect((hijri.day, hijri.month, hijri.year), (10, 6, 1448));
      expect(hijri.labelId, '10 Jumadil Akhir 1448 H');
      expect(hijri.monthNameAr, 'جُمادى الآخرة');
      expect(hijri.weekdayEn, "Al Juma'a");
      expect(hijri.method, 'HJCoSA');
      expect(hijri.holidays, hasLength(1));
    });

    test('madhab Hanafi menggeser Asar tanpa mengubah Subuh', () {
      final hanafi = AladhanPrayerClient.parse(
        jakartaHanafi,
        requestedDateKey: '2026-11-20',
        method: kemenag,
      );
      expect(hanafi.asrMadhab, AsrMadhab.hanafi);
      expect(hanafi.eventFor(PrayerKind.asr)!.wallClock, '16:05');
      expect(hanafi.eventFor(PrayerKind.fajr)!.wallClock, '04:03');
    });
  });

  group('parse menolak data yang tidak bisa dipercaya', () {
    test('status bukan 200/OK', () {
      final payload = _copy(jakartaStandard);
      payload['code'] = 400;
      payload['status'] = 'ERROR';
      expectFailure(
        payload,
        PrayerDataFailureKind.rejected,
        method: kemenag,
        message: 'menolak permintaan',
      );
    });

    test('waktu sholat hilang', () {
      final payload = _copy(jakartaStandard);
      (payload['data']['timings'] as Map).remove('Isha');
      expectFailure(
        payload,
        PrayerDataFailureKind.malformed,
        method: kemenag,
        message: 'Isya tidak dikirim',
      );
    });

    test('jam tanpa offset ditolak, bukan dianggap waktu perangkat', () {
      final payload = _copy(jakartaStandard);
      (payload['data']['timings'] as Map)['Fajr'] = '04:03';
      expectFailure(
        payload,
        PrayerDataFailureKind.malformed,
        method: kemenag,
        message: 'tidak dapat dibaca',
      );
    });

    test('zona waktu tidak dikirim', () {
      final payload = _copy(jakartaStandard);
      (payload['data']['meta'] as Map).remove('timezone');
      expectFailure(
        payload,
        PrayerDataFailureKind.malformed,
        method: kemenag,
        message: 'zona waktu',
      );
    });

    test('metode yang dipakai server berbeda dari yang diminta', () {
      expectFailure(
        jakartaStandard,
        PrayerDataFailureKind.malformed,
        method: PrayerMethod.byId(3),
        message: 'bukan 3',
      );
    });

    test('struktur data tidak dikenal', () {
      expectFailure(
        {'code': 200, 'status': 'OK', 'data': 'unexpected'},
        PrayerDataFailureKind.malformed,
        method: kemenag,
        message: 'struktur respons tidak dikenal',
      );
    });
  });

  group('parseInstant', () {
    test('membaca offset dengan dan tanpa titik dua, serta nol offset', () {
      expect(AladhanPrayerClient.parseInstant('2026-11-20T04:03:00+07:00'), (
        DateTime.utc(2026, 11, 19, 21, 3),
        const Duration(hours: 7),
      ));
      expect(AladhanPrayerClient.parseInstant('2026-11-20T04:03:00+0700'), (
        DateTime.utc(2026, 11, 19, 21, 3),
        const Duration(hours: 7),
      ));
      expect(AladhanPrayerClient.parseInstant('2026-11-20T04:03:00-05:30'), (
        DateTime.utc(2026, 11, 20, 9, 33),
        const Duration(hours: -5, minutes: -30),
      ));
      expect(AladhanPrayerClient.parseInstant('2026-11-20T04:03:00+00:00'), (
        DateTime.utc(2026, 11, 20, 4, 3),
        Duration.zero,
      ));
      expect(AladhanPrayerClient.parseInstant('bukan waktu'), isNull);
    });
  });
}

Map<String, dynamic> _fixture(String name) {
  final file = File('test/fixtures/aladhan/$name');
  if (!file.existsSync()) {
    throw StateError('Fixture hilang: ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _copy(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

void expectFailure(
  Map<String, dynamic> payload,
  PrayerDataFailureKind kind, {
  required PrayerMethod method,
  required String message,
}) {
  Object? thrown;
  try {
    AladhanPrayerClient.parse(
      payload,
      requestedDateKey: '2026-11-20',
      method: method,
    );
  } catch (error) {
    thrown = error;
  }
  expect(thrown, isA<PrayerDataSourceException>());
  final failure = thrown! as PrayerDataSourceException;
  expect(failure.kind, kind);
  expect(failure.message, contains(message));
}

Dio _dio(HttpClientAdapter adapter) =>
    Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)))
      ..httpClientAdapter = adapter;

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.payload);

  final Map<String, dynamic> payload;
  RequestOptions? last;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    calls++;
    last = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        'content-type': ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.error);

  final DioException error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) => throw error;

  @override
  void close({bool force = false}) {}
}
