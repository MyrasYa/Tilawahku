import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/voices/data/surah_audio_catalog.dart';
import 'package:tilawahku/features/voices/data/voice_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Voice luhaidan;

  setUp(() async {
    final voices = await const VoiceCatalog().load();
    luhaidan = voices.singleWhere(
      (voice) => voice.id == 'muhammad-al-luhaidan',
    );
  });

  test('maps all 114 ordered API URLs to matching surah numbers', () {
    final catalog = SurahAudioCatalog.parse(_payload(), luhaidan);

    expect(catalog, hasLength(114));
    for (var index = 0; index < catalog.length; index++) {
      final source = catalog[index];
      expect(source.number, index + 1);
      expect(source.uri.host, 'cdn.islamic.network');
      expect(
        source.uri.path,
        '/quran/audio-surah/128/ar.muhammadalluhaidan/${index + 1}.mp3',
      );
    }
  });

  test('rejects an incomplete surah list', () {
    final payload = _payload();
    final data = payload['data']! as Map<String, dynamic>;
    data['surahs'] = (data['surahs']! as List).take(113).toList();

    expect(
      () => SurahAudioCatalog.parse(payload, luhaidan),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects URLs that do not match edition, bitrate, or surah number', () {
    final payload = _payload();
    final data = payload['data']! as Map<String, dynamic>;
    final surahs = data['surahs']! as List<dynamic>;
    final firstSurah = surahs.first as Map<String, dynamic>;
    firstSurah['audio'] =
        'https://cdn.islamic.network/quran/audio/128/'
        'ar.muhammadalluhaidan/1.mp3';

    expect(
      () => SurahAudioCatalog.parse(payload, luhaidan),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _payload() => {
  'code': 200,
  'status': 'OK',
  'data': {
    'surahs': List.generate(
      114,
      (index) => {
        'number': index + 1,
        'englishName': 'Surah ${index + 1}',
        'audio':
            'https://cdn.islamic.network/quran/audio-surah/128/'
            'ar.muhammadalluhaidan/${index + 1}.mp3',
      },
    ),
  },
};
