import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/prayer_models.dart';

/// Daftar kota pilihan yang dibundel dalam aplikasi.
///
/// Sumber dan tanggal pembuatan tercatat di dalam berkasnya (`_meta`):
/// koordinat dari OpenStreetMap Nominatim (ODbL 1.0), zona waktu dari
/// `api.aladhan.com/v1/timings` `meta.timezone`. Karena datanya lokal,
/// pemilihan kota tetap berfungsi tanpa jaringan.
class CityLocationCatalog {
  CityLocationCatalog({Future<String> Function(String path)? loadAsset})
    : _loadAsset = loadAsset ?? rootBundle.loadString;

  static const assetPath = 'assets/prayer/city_locations.json';

  final Future<String> Function(String path) _loadAsset;
  List<WorshipLocation>? _loaded;

  Future<List<WorshipLocation>> load() async {
    final cached = _loaded;
    if (cached != null) return cached;
    final raw = await _loadAsset(assetPath);
    final entries = decode(raw);
    _loaded = entries;
    return entries;
  }

  static List<WorshipLocation> decode(String raw) {
    Object? payload;
    try {
      payload = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (payload is! Map) return const [];
    final locations = payload['locations'];
    if (locations is! List) return const [];
    return [
      for (final entry in locations)
        if (entry is Map<String, dynamic>) _location(entry),
    ].whereType<WorshipLocation>().toList(growable: false);
  }

  static WorshipLocation? _location(Map<String, dynamic> map) {
    final name = map['name'];
    final latitude = map['latitude'];
    final longitude = map['longitude'];
    // Tipe diperiksa, bukan dipaksa: satu entri cacat tidak boleh menggagalkan
    // seluruh daftar kota.
    if (name is! String ||
        name.isEmpty ||
        latitude is! num ||
        longitude is! num ||
        !WorshipLocation.coordinateInRange(
          latitude.toDouble(),
          longitude.toDouble(),
        )) {
      return null;
    }
    final timezone = map['timezone'];
    final country = map['country'];
    return WorshipLocation(
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      source: LocationSource.saved,
      timezoneId: timezone is String ? timezone : null,
      country: country is String ? country : null,
    );
  }
}
