# PRD 07 — Arah Kiblat: catatan implementasi

Tanggal: 2026-11-21 · Branch: `feature/prd07-qibla`

## 1. Ringkasan

Layar arah kiblat offline-first: bearing lingkaran besar ke Ka'bah dari koordinat
yang sama dengan waktu salat, plus kompas perangkat bila sensor ada, dan dial
manual sebagai cadangan. Diakses dari **Lainnya → Arah kiblat**. Tidak ada tab
baru, tidak ada penyimpanan lokasi kedua, dan tidak ada heading yang dikarang.

## 2. Struktur kode

| Berkas | Peran |
| --- | --- |
| `lib/features/qibla/domain/qibla_direction.dart` | Ka'bah `21.4225, 39.8262`, haversine, bearing awal, normalisasi 0–360, `relativeQibla`, kalibrasi, petunjuk putar |
| `lib/features/qibla/data/qibla_location_store.dart` | Membaca/menyimpan lokasi lewat `PrayerPreferences` |
| `lib/features/qibla/data/qibla_heading.dart` | `QiblaHeadingSample` dan antarmuka `QiblaHeadingSource` |
| `lib/features/qibla/data/qibla_heading_source.dart` | Ekspor bersyarat: native vs web/unsupported |
| `lib/features/qibla/data/qibla_heading_source_native.dart` | `flutter_device_compass` 2.2.0; gagal plugin → tidak tersedia |
| `lib/features/qibla/data/qibla_heading_source_unsupported.dart` | Web/desktop: `hasSensors == false`, stream kosong |
| `lib/features/qibla/presentation/qibla_controller.dart` | State layar, langganan sensor, stale/pause/dispose, fallback manual |
| `lib/features/qibla/presentation/qibla_screen.dart` | Widget baca-saja + dial geser |
| `lib/features/prayer/presentation/location_selection.dart` | Permukaan bersama lembar lokasi waktu salat dan kiblat |

Widget tidak menghitung bearing; mereka membaca properti controller.

## 3. Rumus dan bukti AlAdhan

Titik acuan: 21,4225° LU, 39,8262° BT (pasangan yang dipakai AlAdhan
`/v1/qibla`). Bearing adalah *initial great-circle bearing* dari utara sejati,
dinormalisasi ke `[0, 360)`. Jarak memakai haversine dengan `R = 6371` km.

`relativeQibla = (qiblaBearing - deviceHeading + 360) % 360`

Arah tidak dihitung bila jarak < 1 km (berada di Ka'bah) atau > 20.000 km
(antipod), atau koordinat di luar `-90..90` / `-180..180`.

Cuplikan AlAdhan 2026-11-21 (`GET https://api.aladhan.com/v1/qibla/{lat}/{lng}`):

| Kota | Koordinat | AlAdhan `direction` | Rumus aplikasi | Δ |
| --- | --- | --- | --- | --- |
| Jakarta | -6,175 / 106,827 | 295,1460159830117 | 295,146007 | < 0,001° |
| Bandung | -6,9147 / 107,6098 | 295,1688414325397 | 295,168833 | < 0,001° |
| Madinah | 24,4672 / 39,6111 | 176,23589894082676 | 176,235326 | < 0,001° |
| London | 51,5074 / -0,1278 | 118,98724251452296 | 118,987219 | < 0,001° |
| New York | 40,7128 / -74,006 | 58,481712034206865 | 58,481701 | < 0,001° |
| Sydney | -33,8688 / 151,2093 | 277,499589412883 | 277,499589 | < 0,001° |
| Cape Town | -33,9249 / 18,4241 | 23,35250070951438 | 23,352542 | < 0,001° |

Tidak ada permintaan jaringan saat layar kiblat dihitung. AlAdhan hanya dipakai
sebagai bukti rumus, bukan sumber runtime.

## 4. Lokasi bersama

`QiblaLocationStore` memanggil `PrayerPreferences.load` / `saveLocation`. Satu
pilihan kota atau GPS berlaku untuk waktu salat dan kiblat. Izin lokasi hanya
diminta saat pengguna menekan "Gunakan lokasi perangkat". Penolakan izin
menampilkan pesan `LocationFailure` yang sama dengan PRD 06, plus input kota
atau koordinat.

## 5. Kompas perangkat

Paket: `flutter_device_compass` ^2.2.0 (fork terawat dari `flutter_compass`;
`sensors_plus` 7.x meminta AGP di atas toolchain proyek ini).

* Android/iOS: `FlutterCompass.hasSensors` lalu `FlutterCompass.events`.
* Web dan desktop: stub unsupported; dial manual.
* Heading `null`, non-finite, atau akurasi negatif tidak dipakai.
* Tidak ada sampel selama 3 detik → mode manual + pesan "bacaan terhenti".
* `AppLifecycle` pause memutus langganan; resume memasang ulang.
* `dispose` membatalkan timer dan stream.

Plugin memetakan akurasi Android `-1` menjadi `null`, jadi status
"unreliable" native tidak selalu sampai ke Dart. UI tetap menolak heading
`null` dan menampilkan kalibrasi bila akurasi ≥ 15°.

iOS: plugin memakai Core Location untuk heading. Izin lokasi yang sudah ada
dari waktu salat dipakai; aplikasi tidak meminta izin "always". Bila heading
iOS tidak muncul tanpa izin, dial manual tetap ada.

## 6. Privasi

Perhitungan kiblat lokal. Koordinat tidak dikirim ke server untuk bearing.
GPS hanya untuk mengisi preferensi lokasi bersama. Kompas tidak memakai
jaringan.

## 7. Pengujian

| Berkas | Isi |
| --- | --- |
| `test/qibla_direction_test.dart` | AlAdhan, normalisasi, jarak, kutub, Ka'bah, antipod, koordinat rusak, rumus relatif |
| `test/qibla_heading_source_test.dart` | stub unsupported, platform tanpa sensor, kegagalan plugin, pemetaan event |
| `test/qibla_controller_test.dart` | lokasi bersama, izin, live/manual, stale, pause/resume, dispose, dial |
| `test/qibla_screen_test.dart` | panel lokasi, bearing Jakarta, mode live, kalibrasi, gagal GPS |
| `test/qibla_navigation_test.dart` | Lainnya → Arah kiblat, bukan "Belum tersedia" |

## 8. Status verifikasi per platform

| Platform | Status |
| --- | --- |
| Web | Unit/widget test + `flutter build web --release`. Kompas **tidak** diaktifkan; dial manual. |
| Windows (tes VM) | `defaultTargetPlatform` di tes sering Android, tetapi `hasSensors` plugin ditangkap dan jatuh ke manual. |
| Android | **BELUM TERVERIFIKASI di perangkat.** Sensor, kalibrasi, dan heading magnetik belum diuji di hardware. |
| iOS | **BELUM TERVERIFIKASI di perangkat.** |

## 9. Sisa pekerjaan yang diketahui

* Verifikasi kompas live di ponsel Android dan iOS (kalibrasi angka-8, casing
  magnet, rotasi lanskap).
* Deklinasi magnetik tidak diterapkan: dial manual memakai utara sejati.
* Plugin tidak membedakan akurasi Android `-1` setelah dipetakan ke `null`.
