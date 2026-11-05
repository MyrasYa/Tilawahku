# Design — TILAWAHKU

Spesifikasi desain visual dan UX, diturunkan dari PRD TILAWAHKU v1.0 (23 Oktober 2026).

## 1. Prinsip Desain

- **Biru tua dan emas** sebagai identitas visual utama — nuansa khidmat, tenang, dan mudah dibaca dalam waktu lama.
- **Mode anak:** tombol besar, ikon sederhana, sedikit pilihan per layar.
- **Teks Arab** berukuran besar dan lega, dengan penanda akhir ayat berwarna emas.
- **Ayat aktif** (sedang diputar) disorot emas lembut, dengan auto-scroll.
- **Aksesibilitas:** ukuran huruf dapat diperbesar, kontras tinggi, target sentuh minimal 48 dp.

## 2. Palet Warna

| Peran | Warna | Hex |
| --- | --- | --- |
| Biru tua utama | Latar utama, header | #0B2A5B |
| Biru tua gelap | Latar mode gelap | #071B3D |
| Emas aksen | Sorotan, aksen, tombol penting | #C9A227 |
| Teks Arab | Warna huruf Rasm Utsmani | #F8F5EC |
| Terjemahan | Warna teks terjemahan Indonesia | #C9D3E6 |

## 3. Tipografi

| Elemen | Font | Catatan |
| --- | --- | --- |
| Teks Arab | KFGQPC Hafs (bila izin tertulis diperoleh) | Bila belum, gunakan font Qur'an lain yang lisensinya jelas mengizinkan penggunaan di aplikasi — baca lisensinya sebelum dipakai |
| Terjemahan & UI | Sans-serif Latin, legible, mendukung skala ukuran | Ukuran dapat diperbesar lewat Pengaturan |

## 4. Peta Layar (Information Architecture)

```
Splash
  → Onboarding (3 slide: baca, dengar & ulang, offline)
    → Pilih Suara
      → Beranda (30 Juz / Surah, tombol "Lanjutkan Terakhir")
        → Halaman Baca (Utsmani + Terjemahan)
          → Pemutar & Mode Ulang
        ↘ Unduhan (per juz, per suara)
        → Pengaturan
        → Tentang & Sumber
```

## 5. Rincian Layar

### Splash

Logo TILAWAHKU di atas latar biru tua (#0B2A5B).

### Onboarding

3 slide singkat yang menjelaskan: baca Rasm Utsmani + terjemahan, dengar dan ulang murottal, dan mode offline penuh.

### Pilih Suara

Kartu untuk tiap suara: **Husary (Muallim)**, **Minshawi (Anak Mengulang)**, dan **Anak Perempuan** (berlabel "Segera hadir" bila belum tersedia, kartu nonaktif/tidak bisa dipilih). Setiap kartu memiliki tombol pratinjau audio.

### Beranda

Daftar 30 juz, tab daftar 114 surah, dan tombol "Lanjutkan Terakhir" yang mengarah ke posisi baca/dengar terakhir pengguna.

### Unduhan

Saat pengguna memilih juz yang audionya belum tersedia secara lokal, aplikasi menampilkan ukuran unduhan dan menawarkan unduh. Mendukung progres, jeda/lanjut, dan batal. Opsional hanya-Wi-Fi.

### Halaman Baca

Teks Rasm Utsmani dengan terjemahan Indonesia di bawah tiap ayat (dapat disembunyikan/ditampilkan). Ayat yang sedang diputar disorot emas. Navigasi per juz, per surah, dan per halaman; pencarian surah berdasarkan nama atau nomor.

### Pemutar & Mode Ulang

Kontrol play/pause/ayat sebelumnya/berikutnya, kecepatan putar (0,75x–1,5x), timer tidur (15/30/60 menit, akhir surah), dan panel pengaturan pengulangan: ulang 1 ayat, rentang ayat, 1 surah/juz, atau tanpa batas, dengan jeda antar-ulangan yang dapat diatur dan indikator sisa pengulangan.

### Pengaturan

Ganti suara, ukuran huruf, mode gelap, opsi unduhan (Wi-Fi saja), kelola unduhan per juz/suara.

### Tentang & Sumber

Atribusi lengkap: sumber teks, font, terjemahan, dan qari/qariah.

## 6. Mode Gelap

Latar beralih ke biru tua gelap (#071B3D), aksen emas (#C9A227) tetap dipertahankan untuk kontras dan konsistensi identitas.

## 7. Komponen Kunci

- **Kartu suara** (status: aktif / segera hadir)
- **Baris ayat** (teks Arab + terjemahan + indikator sorotan)
- **Mini-player** (persisten di bawah layar baca)
- **Panel mode ulang** (slider/stepper untuk N kali ulang, rentang ayat, jeda)
- **Kartu unduhan** (ukuran, progres, aksi jeda/lanjut/batal/hapus)
- **Notifikasi & layar kunci** (kontrol audio dari luar aplikasi)

## 8. Catatan Lisensi Desain

Font Arab KFGQPC milik King Fahd Glorious Quran Printing Complex memerlukan izin tertulis untuk reproduksi atau modifikasi. Tim desain harus memastikan status izin ini sebelum font dikunci sebagai final, atau menyiapkan font alternatif berlisensi jelas sebagai cadangan.
