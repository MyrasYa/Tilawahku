# PRD 06 — Waktu Salat: catatan implementasi

Tanggal: 2026-11-20 · Branch: `feature/prd06-prayer-times`

## 1. Ringkasan

Layar waktu salat offline-first: jadwal harian dari AlAdhan API v1, hitung mundur
ke waktu berikutnya, navigasi hari, penyesuaian menit manual, pilihan metode dan
mazhab Asar, pengingat lokal, serta katalog kota yang dibundel dalam aplikasi.
Diakses dari Dashboard melalui navigasi bawah yang sudah ada — tidak ada tab baru
dan tidak ada sistem penyimpanan kedua.

## 2. Struktur kode

| Berkas | Peran |
| --- | --- |
| `lib/features/prayer/domain/prayer_models.dart` | `PrayerKind`, `PrayerEvent`, `PrayerDaySchedule`, `HijriDate`, `WorshipLocation`, `PrayerSettings`, `PrayerAdjustments`, `scheduleCacheKey`, `prayerCacheTtl` |
| `lib/features/prayer/domain/prayer_method.dart` | Katalog metode AlAdhan yang terverifikasi + `AsrMadhab` |
| `lib/features/prayer/domain/prayer_countdown.dart` | `nextSalatEvent`, `currentSalatEvent`, `dateKeyFor`, `shiftDateKey`, `needsFollowingDay`, format hitung mundur |
| `lib/features/prayer/domain/prayer_reminder.dart` | `PrayerReminder`, `PrayerReminderPolicy`, antarmuka `PrayerReminderScheduler` |
| `lib/features/prayer/data/aladhan_prayer_client.dart` | `PrayerDaySource` (seam uji) + klien HTTP AlAdhan dan parsing stamp ISO-8601 beroffset |
| `lib/features/prayer/data/prayer_cache_store.dart` | Antarmuka cache + implementasi SQLite |
| `lib/features/prayer/data/prayer_preferences.dart` | Preferensi `prayer_*` di `AppPreferences` |
| `lib/features/prayer/data/city_location_catalog.dart` | Pembacaan `assets/prayer/city_locations.json` (dimemo sekali) |
| `lib/features/prayer/data/device_location.dart` | `DeviceLocationProvider` + pemetaan kegagalan izin GPS |
| `lib/features/prayer/data/prayer_reminder_scheduler*.dart` | Implementasi notifikasi (Android/iOS) dan versi tanpa dukungan (web/desktop) |
| `lib/features/prayer/data/prayer_repository.dart` | Kebijakan: jaringan vs cache, pratarik, penyingkiran cache, sinkronisasi pengingat |
| `lib/features/prayer/presentation/prayer_times_controller.dart` | Seluruh state dan aksi layar; satu-satunya tempat ticker 1 detik |
| `lib/features/prayer/presentation/prayer_times_screen.dart` | Widget baca-saja |
| `lib/features/prayer/presentation/prayer_setup_sheets.dart` | Lembar pemilihan lokasi dan pengaturan jadwal |

Logika tidak ada yang berada di widget; widget hanya membaca properti controller
dan memanggil aksinya.

## 3. Sumber data eksternal dan lisensi

* **AlAdhan API v1** — `https://api.aladhan.com/v1/timings/{DD-MM-YYYY}` dan
  `/v1/methods`. Tanpa kunci API dan tanpa kebutuhan akun. Respons dibaca dengan
  `iso8601=true` sehingga setiap waktu adalah titik UTC mutlak + offset lokasi.
* **Katalog kota** — `assets/prayer/city_locations.json`, 37 entri. Koordinat dari
  OpenStreetMap Nominatim (lisensi ODbL 1.0), zona waktu dari `meta.timezone`
  AlAdhan v1. Dibangkitkan oleh
  `research/Tilawahku-asr-poc/prd-master/build_city_locations.py`; meta sumber,
  tanggal pembuatan, dan lokasi skrip pembangkit ditulis di blok `_meta` berkas
  itu.
* Tidak ada sumber keagamaan teks (ayat/hadis) yang dipakai pada PRD ini.

Cuplikan respons asli disimpan sebagai fixture di
`test/fixtures/aladhan/` dan log mentah di
`research/Tilawahku-asr-poc/prd-master/evidence/`, jadi angka yang diuji bukan
karangan.

## 4. Kebijakan data: lokal, cache, server

* **Lokal selalu:** katalog kota, preferensi, metode, koordinat manual.
* **Cache:** tabel `prayer_schedule_cache` kunci
  `tanggal|koordinat-pembundel|metode-2desimal|mazhab`. Masa berlaku hari ini
  12 jam (`prayerCacheTtl`), retensi baris 400 hari, dipangkas saat layar dibuka.
* **Server:** hanya bila cache tidak ada atau melewati masa berlaku;
  `refresh` (tombol muat ulang) adalah satu-satunya jalan untuk memaksa
  permintaan, dan hanya untuk tanggal yang tampil.
* **Pratarik:** setelah hari ini berhasil diunduh, hari berikutnya ikut disimpan
  sekali sehingga berganti hari tidak memerlukan jaringan.
* **Tanggal lampau** tidak pernah diminta ulang walaupun cache-nya tua — waktu
  salat adalah hasil hitung dan tidak berubah setelah hari itu lewat.
* **Permintaan seragam yang bersamaan dipakai bersama** (peta in-flight per
  kunci), jadi pratarik dan permintaan layar tidak mengunduh hari yang sama dua
  kali.
* **Luring:** ada cache → jadwal tetap tampil dengan catatan
  "Jadwal berasal dari cache karena server tidak dapat dihubungi: …"; tidak ada
  cache → layar kegagalan dengan tombol coba lagi dan ganti lokasi, bukan jadwal
  kosong.

## 5. Skema database

`DatabaseSchema.version` naik 6 → 7, murni aditif: satu tabel
`prayer_schedule_cache` (kata kunci `cache_key` sebagai PRIMARY KEY, kolom
`date_key`, `location_key`, `method_id`, `asr_madhab`, `timezone_id`,
`offset_minutes`, `events_json`, `hijri_json`, `fetched_at`) dan satu indeks
`prayer_schedule_day_idx ON prayer_schedule_cache (date_key, location_key)`.
Tidak ada `DROP`, tidak ada `ALTER`, tidak ada tabel preferensi baru (preferensi
tetap di `AppPreferences`). Blok `if (oldVersion < 7)` ada di
`app_database_native.dart` **dan** `app_database_web.dart`; `test/prayer_schema_test.dart`
menjaga keduanya tetap setara.

## 6. Privasi dan izin

* `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION` diminta hanya ketika
  pengguna menekan "Gunakan lokasi perangkat". Tidak ada pelacakan berkelanjutan
  dan tidak ada riwayat lokasi yang disimpan atau dikirim.
* Koordinat hanya dipakai untuk permintaan jadwal ke `api.aladhan.com`.
* `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM` dipakai
  untuk pengingat; dua receiver `flutter_local_notifications` ditambahkan agar
  alarm tersusun ulang setelah perangkat dinyalakan ulang.
* Aplikasi menjelaskan pemakaian lokasi di UI (panel "tentukan lokasi" dan
  catatan sumber), dan penolakan izin menampilkan alasan plus jalan manual.

## 7. Batasan konten keagamaan

* Waktu salat adalah **hasil perhitungan** AlAdhan untuk koordinat + metode
  terpilih; UI menyatakan tanggal Hijriah sebagai perhitungan layanan, **bukan**
  penetapan resmi pemerintah atau hasil rukyat.
* Perbedaan mazhab Asar (Standard/Hanafi) disajikan sebagai pilihan pengguna, dan
  metode ditampilkan dengan sudutnya masing-masing, bukan sebagai satu-satunya
  pendapat benar.
* Penyesuaian manual diberi label "+/- n menit" pada tiap waktu agar terlihat
  sebagai campur tangan pengguna, bukan angka server.

## 8. Pengujian

98 tes PRD 06 (`flutter test`, semuanya lolos):

| Berkas | Jumlah | Isi |
| --- | --- | --- |
| `test/aladhan_prayer_client_test.dart` | 15 | pembentukan URL, parsing fixture nyata, penolakan respons cacat, pemetaan kegagalan |
| `test/prayer_method_catalog_test.dart` | 14 | metode vs `/v1/methods`, `AsrMadhab`, validasi penyesuaian, kunci cache |
| `test/prayer_countdown_test.dart` | 14 | hitung mundur, batas waktu, tanggal lokasi vs perangkat, lompat bulan/tahun kabisat |
| `test/prayer_reminder_policy_test.dart` | 10 | rencana pengingat: waktu lewat dibuang, lead, clamping, id stabil |
| `test/prayer_repository_test.dart` | 19 | kebijakan cache/pratarik/luring/dedupe, sinkronisasi pengingat, prune |
| `test/prayer_preferences_test.dart` | 9 | round-trip preferensi, nilai rusak tidak membuat layar crash |
| `test/prayer_schema_test.dart` | 5 | migrasi v7 aditif dan setara native/web |
| `test/prayer_times_screen_test.dart` | 12 | layar dengan fakes: kebutuhan lokasi, izin ditolak, pilih kota, hitung mundur, pengingat, luring, navigasi hari, ganti metode |

Regresi: `dart analyze lib test tools` bersih dan `flutter test` 153/153 lolos
(55 tes fitur lama tetap hijau setelah skema naik ke v7).

## 9. Status verifikasi per platform

| Platform | Status |
| --- | --- |
| Web | `flutter build web --release` berhasil; unit + widget test lolos. Pengingat salat **tidak** diaktifkan di web: `supportsPlatform` `false` dan UI mengatakan platform tidak mendukung. |
| Android | **BELUM TERVERIFIKASI.** Mesin pengembangan ini tidak punya Android SDK/adb/perangkat, jadi build APK, izin lokasi, dan notifikasi terjadwal belum dijalankan. Kode dan manifest disiapkan, tetapi tidak ada klaim berfungsi sebelum diuji di perangkat. |
| iOS/desktop | Tidak ditargetkan; scheduler mengembalikan `UnsupportedPrayerReminderScheduler`. |

## 10. Sisa pekerjaan yang diketahui

* Verifikasi perangkat Android: izin lokasi, alarm presisi, notifikasi setelah
  reboot, dan waktu yang benar terhadap zona WIB/WITA/WIT.
* `SCHEDULE_EXACT_ALARM` pada Android 14 dapat dibatasi pengguna; layar belum
  punya petunjuk khusus bila alarm tidak presisi.
* Katalog kota hanya 37 entri; kota lain harus diisi manual sampai ada sumber
  bundled yang lebih luas.
* Hijriah mengikuti perhitungan AlAdhan (`method` dilaporkan tetapi tidak
  ditampilkan sebagai otoritas).
