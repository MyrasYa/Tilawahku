import 'dart:convert';

import 'package:flutter/services.dart';

enum VoiceStatus {
  active('aktif'),
  comingSoon('segera_hadir'),
  disabled('nonaktif');

  const VoiceStatus(this.value);

  final String value;

  static VoiceStatus parse(String value) => VoiceStatus.values.firstWhere(
    (status) => status.value == value,
    orElse: () => throw FormatException('Status suara tidak dikenal: $value'),
  );
}

enum VoiceAudioMode {
  ayah('ayah'),
  surah('surah');

  const VoiceAudioMode(this.value);

  final String value;

  static VoiceAudioMode parse(String value) => VoiceAudioMode.values.firstWhere(
    (mode) => mode.value == value,
    orElse: () =>
        throw FormatException('Mode audio qari tidak dikenal: $value'),
  );
}

class Voice {
  const Voice({
    required this.id,
    required this.name,
    required this.style,
    required this.status,
    required this.audioMode,
    required this.editionId,
    required this.bitrateKbps,
    required this.attribution,
  });

  final String id;
  final String name;
  final String style;
  final VoiceStatus status;
  final VoiceAudioMode audioMode;
  final String editionId;
  final int bitrateKbps;
  final String attribution;

  factory Voice.fromJson(Map<String, dynamic> json) => Voice(
    id: json['id'] as String,
    name: json['nama'] as String,
    style: json['gaya'] as String,
    status: VoiceStatus.parse(json['status'] as String),
    audioMode: VoiceAudioMode.parse(json['audio_mode'] as String),
    editionId: json['edition_id'] as String,
    bitrateKbps: json['bitrate_kbps'] as int,
    attribution: json['attribution'] as String,
  );
}

class VoiceCatalog {
  const VoiceCatalog();

  Future<List<Voice>> load() async {
    final source = await rootBundle.loadString('assets/config/suara.json');
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final schemaVersion = decoded['schema_version'] as int?;
    if (schemaVersion != 1) {
      throw FormatException(
        'Versi katalog suara tidak didukung: $schemaVersion',
      );
    }
    final entries = decoded['suara'] as List<dynamic>;
    final voices = entries
        .map((entry) => Voice.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
    if (voices.map((voice) => voice.id).toSet().length != voices.length) {
      throw const FormatException('ID suara dalam katalog harus unik.');
    }
    return voices;
  }
}
