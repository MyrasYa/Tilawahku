import 'package:dio/dio.dart';

import 'voice_catalog.dart';

class SurahAudioSource {
  const SurahAudioSource({
    required this.number,
    required this.name,
    required this.uri,
  });

  final int number;
  final String name;
  final Uri uri;
}

class SurahAudioCatalog {
  SurahAudioCatalog({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  static const apiBaseUrl = 'https://api.alquran.cloud/v1/quran';
  final Dio _dio;

  Future<List<SurahAudioSource>> load(Voice voice) async {
    if (voice.audioMode != VoiceAudioMode.surah) {
      throw ArgumentError.value(
        voice.audioMode,
        'voice.audioMode',
        'Surah audio is required.',
      );
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '$apiBaseUrl/${Uri.encodeComponent(voice.editionId)}',
    );
    final payload = response.data;
    if (payload == null) {
      throw const FormatException('API tidak mengembalikan data audio surah.');
    }
    return parse(payload, voice);
  }

  static List<SurahAudioSource> parse(
    Map<String, dynamic> payload,
    Voice voice,
  ) {
    if (voice.audioMode != VoiceAudioMode.surah) {
      throw ArgumentError.value(
        voice.audioMode,
        'voice.audioMode',
        'Surah audio is required.',
      );
    }
    if (payload['code'] != 200 || payload['status'] != 'OK') {
      throw const FormatException('API audio surah mengembalikan kegagalan.');
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Format data audio surah tidak valid.');
    }
    final rawSurahs = data['surahs'];
    if (rawSurahs is! List || rawSurahs.length != 114) {
      throw FormatException(
        'Katalog audio harus mencakup 114 surah, '
        'ditemukan ${rawSurahs is List ? rawSurahs.length : 0}.',
      );
    }

    final sources = <SurahAudioSource>[];
    for (var index = 0; index < rawSurahs.length; index++) {
      final rawSurah = rawSurahs[index];
      if (rawSurah is! Map<String, dynamic>) {
        throw FormatException('Metadata surah ${index + 1} tidak valid.');
      }
      final number = rawSurah['number'];
      final name = rawSurah['englishName'];
      final audio = rawSurah['audio'];
      if (number != index + 1 ||
          name is! String ||
          name.isEmpty ||
          audio is! String) {
        throw FormatException(
          'Metadata atau audio surah ${index + 1} tidak lengkap/berurutan.',
        );
      }

      final uri = Uri.tryParse(audio);
      final segments = uri?.pathSegments;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'cdn.islamic.network' ||
          segments == null ||
          segments.length != 5 ||
          segments[0] != 'quran' ||
          segments[1] != 'audio-surah' ||
          segments[2] != voice.bitrateKbps.toString() ||
          segments[3] != voice.editionId ||
          segments[4] != '$number.mp3') {
        throw FormatException(
          'URL audio surah ${index + 1} tidak sesuai metadata sumber.',
        );
      }

      sources.add(SurahAudioSource(number: number, name: name, uri: uri));
    }
    return List.unmodifiable(sources);
  }
}
