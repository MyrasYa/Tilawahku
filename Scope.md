# Scope — TILAWAHKU

Ruang lingkup v1, diturunkan dari PRD TILAWAHKU v1.0 (23 Oktober 2026).

## 1. Ringkasan Produk (konteks)

TILAWAHKU adalah aplikasi Al-Qur'an offline-first (Android v1, iOS v1.1) dengan teks Rasm Utsmani, terjemahan Indonesia, dan murottal gaya muallim yang bisa diulang per ayat, rentang ayat, surah, atau juz. Model bisnis v1: gratis, tanpa iklan.

## 2. Termasuk dalam v1

### Konten

- Teks Rasm Utsmani 30 juz dan 114 surah, riwayat Hafs 'an 'Asim
- Terjemahan Bahasa Indonesia per ayat

### Suara & Audio

- Pemilihan suara saat awal pemakaian dan dapat diganti di Pengaturan
- Pemutar audio per ayat dengan sorotan ayat aktif
- Unduhan audio per juz dan per suara, dengan mode offline penuh

### Mode Ulang

- Ulang satu ayat, rentang ayat, satu surah, satu juz, atau tanpa batas

### Fitur Pendukung

- Bookmark ayat
- Lanjutkan Terakhir
- Timer tidur
- Kecepatan putar
- Tema biru dan emas, mode gelap
- Halaman Tentang & Sumber

## 3. Di luar v1 (eksplisit tidak dikerjakan)

| Item | Alasan/Catatan |
| --- | --- |
| Tafsir | Ditunda, bukan kebutuhan inti v1 |
| Tajwid berwarna | Ditunda |
| Tebak ayat (gamifikasi) | Ditunda |
| Fitur sosial | Ditunda |
| Akun pengguna & sinkronisasi antar-perangkat | Di luar skop offline-first v1 |
| Iklan & pembayaran dalam aplikasi | Model bisnis v1 adalah gratis tanpa iklan |
| Rekaman suara pengguna & penilaian bacaan otomatis | Fitur lanjutan, butuh riset terpisah |
| Qiraat selain Hafs | Hanya riwayat Hafs 'an 'Asim di v1 |

## 4. Batasan Platform & Teknis

| Aspek | Batasan |
| --- | --- |
| Platform v1 | Android saja (iOS menyusul di v1.1) |
| Perangkat minimum | Android 8.0 ke atas, termasuk perangkat berspesifikasi rendah |
| Sumber data | api.alquran.cloud, diambil sekali lewat skrip (tidak dipanggil langsung oleh aplikasi) |
| Mode | Offline-first; internet hanya untuk unduhan paket dan update konfigurasi |

## 5. Batasan Suara v1

- Suara aktif di awal: **Husary (Muallim)** dan **Minshawi (Muallim, anak-anak mengulang)**
- Kategori **suara perempuan/anak perempuan**: slot disiapkan, berstatus "segera hadir" sampai rekaman berlisensi jelas tersedia

## 6. Kriteria Keluar dari Scope (Out-of-Scope Triggers)

Permintaan/perubahan berikut dianggap di luar scope v1 kecuali disetujui ulang sebagai perubahan PRD:

- Penambahan qiraat selain Hafs
- Penambahan akun pengguna atau sinkronisasi cloud
- Penambahan iklan atau mekanisme pembayaran
- Penambahan tafsir atau konten keagamaan tambahan di luar teks dan terjemahan resmi

## 7. Dependensi Scope

- Ketersediaan edisi audio Husary/Minshawi gaya muallim di api.alquran.cloud (format per ayat, bukan per surah) — menentukan apakah mode ulang per ayat bisa berjalan penuh.
- Kejelasan lisensi font KFGQPC, terjemahan Kemenag, dan audio qari — menentukan apakah rilis tetap gratis atau perlu penyesuaian scope konten.
