import 'dart:convert';

import 'package:flutter/services.dart';

/// Peta ejaan Uthmani -> Imlaei yang dipakai engine perbandingan kata.
///
/// Sumber: salinan `asr-spike/spelling.json` dari PoC ASR, 2.111 pasangan,
/// SHA-256 `77f540d470454f57605f0b46cfea92cfda8d051c45e72689b874ef5929370498`.
/// Provenance aslinya tidak terdokumentasi (dihasilkan spike yang hilang), jadi
/// isinya hanya meratakan perbedaan ortografi dan tidak boleh diperlakukan
/// sebagai penentu benar atau salahnya bacaan.
class AssessmentLexicon {
  const AssessmentLexicon();

  static const String assetPath = 'assets/assessment/spelling.json';

  Future<Map<String, String>> load() async =>
      parse(await rootBundle.loadString(assetPath));

  static Map<String, String> parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Peta ejaan harus berupa objek JSON.');
    }
    for (final entry in decoded.entries) {
      if (entry.key.trim().isEmpty || entry.key.contains(' ')) {
        throw FormatException('Kunci peta ejaan tidak valid: ${entry.key}');
      }
      if (entry.value is! String || (entry.value as String).trim().isEmpty) {
        throw FormatException('Nilai peta ejaan tidak valid: ${entry.key}');
      }
    }
    return decoded.map((key, value) => MapEntry(key, value as String));
  }
}

Future<Map<String, String>> loadAssessmentSpellingMap() =>
    const AssessmentLexicon().load();
