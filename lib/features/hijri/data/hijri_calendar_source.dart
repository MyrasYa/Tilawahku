import 'package:dio/dio.dart';

import '../../prayer/data/aladhan_prayer_client.dart';
import '../../prayer/domain/prayer_models.dart';
import '../domain/hijri_models.dart';

/// Kontrak sumber kalender bulanan.
///
/// Dipisahkan dari `AladhanPrayerClient` supaya kalender dapat diuji
/// dengan sumber tiruan tanpa ketergantungan HTTP.
abstract interface class HijriCalendarSource {
  Future<HijriCalendarMonth> fetchMonth({
    required int gregorianYear,
    required int gregorianMonth,
    required WorshipLocation location,
  });
}

/// Implementasi default untuk sumber kalender bulanan.
class AladhanHijriCalendarSource implements HijriCalendarSource {
  AladhanHijriCalendarSource({Dio? dio, Uri? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      _baseUrl = baseUrl ?? Uri.parse('https://api.aladhan.com/v1');

  final Dio _dio;
  final Uri _baseUrl;

  @override
  Future<HijriCalendarMonth> fetchMonth({
    required int gregorianYear,
    required int gregorianMonth,
    required WorshipLocation location,
  }) async {
    final uri = _baseUrl.replace(
      path: '/v1/calendar',
      queryParameters: {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'month': '$gregorianMonth',
        'year': '$gregorianYear',
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
        'Kalender Hijri tidak dapat dibaca: respons kosong.',
      );
    }
    return AladhanPrayerClient.parseCalendar(
      payload,
      gregorianYear,
      gregorianMonth,
    );
  }

  static PrayerDataSourceException _mapTransportError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const PrayerDataSourceException(
        PrayerDataFailureKind.timeout,
        'Kalender Hijri tidak dapat diambil tepat waktu. Periksa koneksi lalu '
        'coba lagi.',
      ),
      DioExceptionType.connectionError => const PrayerDataSourceException(
        PrayerDataFailureKind.offline,
        'Perangkat sedang luring. Kalender yang tersimpan dipakai bila ada.',
      ),
      DioExceptionType.badResponse => PrayerDataSourceException(
        PrayerDataFailureKind.server,
        'Layanan kalender membalas ${error.response?.statusCode}. '
        'Coba lagi beberapa saat.',
      ),
      _ => const PrayerDataSourceException(
        PrayerDataFailureKind.server,
        'Layanan kalender sedang tidak dapat dihubungi.',
      ),
    };
  }

  void close() => _dio.close(force: true);
}
