import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/core/database/database_schema.dart';

/// Migrasi v7 menambah cache jadwal sholat. Yang dijaga di sini: migrasi harus
/// tambahan (forward-only), dan kedua implementasi `AppDatabase` (native dan
/// web) harus memakainya — kalau salah satu tertinggal, pengguna platform
/// tertentu tidak punya tabelnya saat layar waktu sholat dibuka.
void main() {
  test('versi skema naik satu langkah menjadi 8 atau lebih', () {
    expect(DatabaseSchema.version, greaterThanOrEqualTo(8));
  });

  test(
    'pernyataan v7 adalah tabel dan indeks baru tanpa mengubah yang lama',
    () {
      expect(DatabaseSchema.prayerCreateStatements, hasLength(2));
      expect(
        DatabaseSchema.createStatements,
        containsAll(DatabaseSchema.prayerCreateStatements),
      );
      for (final statement in DatabaseSchema.prayerCreateStatements) {
        final head = statement.trim();
        expect(
          head,
          anyOf(startsWith('CREATE TABLE'), startsWith('CREATE INDEX')),
        );
        expect(head, isNot(contains('DROP')));
        expect(head, isNot(contains('ALTER')));
      }
      expect(
        DatabaseSchema.createPrayerScheduleCache.trim(),
        startsWith('CREATE TABLE prayer_schedule_cache'),
      );
    },
  );

  test('cache jadwal menyimpan kunci lengkap dan nilai server apa adanya', () {
    final table = DatabaseSchema.createPrayerScheduleCache;
    for (final column in [
      'cache_key TEXT PRIMARY KEY',
      'date_key TEXT NOT NULL',
      'location_key TEXT NOT NULL',
      'method_id INTEGER NOT NULL',
      'asr_madhab TEXT NOT NULL',
      'timezone_id TEXT NOT NULL',
      'offset_minutes INTEGER NOT NULL',
      'events_json TEXT NOT NULL',
      'fetched_at TEXT NOT NULL',
    ]) {
      expect(table, contains(column));
    }
    // Penyesuaian manual sengaja tidak punya kolom: hanya waktu dari server
    // yang boleh tersimpan, koreksi terjadi di sisi aplikasi.
    expect(table, isNot(contains('adjustment')));
    expect(
      DatabaseSchema.createPrayerScheduleDayIndex,
      contains('ON prayer_schedule_cache (date_key, location_key)'),
    );
  });

  test('native dan web menjalankan blok migrasi v7 yang sama', () {
    for (final path in [
      'lib/core/database/app_database_native.dart',
      'lib/core/database/app_database_web.dart',
    ]) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path hilang');
      final source = file.readAsStringSync();
      expect(source, contains('if (oldVersion < 7)'), reason: '$path tanpa v7');
      expect(
        source,
        contains('DatabaseSchema.prayerCreateStatements'),
        reason: '$path tidak membuat tabel cache sholat',
      );
    }
  });

  test('nama tabel baru tidak menimpa tabel fitur lama', () {
    final tables = [
      for (final statement in DatabaseSchema.createStatements)
        if (statement.trim().startsWith('CREATE TABLE'))
          RegExp(r'CREATE TABLE (\w+)').firstMatch(statement)!.group(1)!,
    ];
    expect(tables.toSet(), hasLength(tables.length));
    expect(tables, contains('prayer_schedule_cache'));
    expect(tables, containsAll(['surah', 'ayah', 'suara', 'audio']));
  });
}
