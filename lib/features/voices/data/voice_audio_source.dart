import 'voice_catalog.dart';

class VoiceAudioSource {
  const VoiceAudioSource._();

  static const baseUrl = 'https://cdn.islamic.network/quran/audio';

  static String urlFor(Voice voice, int globalAyahNumber) =>
      '$baseUrl/${voice.bitrateKbps}/${voice.editionId}/'
      '$globalAyahNumber.mp3';
}
