# PRD — TILAWAHKU

*Aplikasi Al-Qur'an offline dengan Rasm Utsmani, terjemahan Indonesia, dan murottal gaya muallim* Versi 1.0 (draf) · 23 Oktober 2026

## 1. Ringkasan Produk

**TILAWAHKU** adalah aplikasi seluler (Android lebih dulu, iOS menyusul) untuk membaca Al-Qur'an dalam **Rasm Utsmani** beserta **terjemahan Indonesia**, dan mendengarkan murottal yang **bisa diulang** pada tingkat ayat, rentang ayat, surah, atau juz. Seluruh 30 juz tersedia. Aplikasi dirancang **offline-first**: teks dan terjemahan sudah ada di dalam aplikasi, sedangkan audio diunduh per juz sekali, lalu diputar tanpa internet.

Pengguna memilih suara di awal. Pilihan awal adalah **Husary (gaya muallim)** dan **Minshawi (gaya muallim, anak-anak mengulang)**. Kategori **suara perempuan/anak perempuan** disiapkan sebagai slot yang aktif bila rekaman berlisensi jelas tersedia.

| Item | Keputusan |
| --- | --- |
| Nama | TILAWAHKU |
| Warna | Biru tua dan emas |
| Teks | Rasm Utsmani (riwayat Hafs) + terjemahan Indonesia |
| Mode | Offline-first |
| Sumber data | api.alquran.cloud (diambil sekali lewat skrip, bukan dipanggil dari aplikasi) |
| Platform | Android (v1), iOS (v1.1) |
| Model bisnis v1 | Gratis, tanpa iklan |

## 2. Latar Belakang dan Masalah

Orang tua dan guru ngaji membutuhkan alat bantu belajar dan menghafal yang memungkinkan pengulangan bacaan tanpa batas. Masalah yang ingin diselesaikan:

- Banyak aplikasi Al-Qur'an bergantung pada internet, padahal pengguna sering belajar di tempat dengan sinyal lemah atau kuota terbatas.
- Murottal gaya muallim, yaitu qari membaca lalu anak-anak mengulang, jarang dikemas dengan fitur pengulangan per ayat yang mudah dipakai.
- Pengguna anak membutuhkan antarmuka sederhana, dengan tombol besar dan alur yang tidak membingungkan.
- Pengembang sering mengabaikan lisensi teks, font, terjemahan, dan audio, sehingga aplikasi berisiko dihapus dari toko aplikasi.

## 3. Tujuan dan Metrik Keberhasilan

### Tujuan

- Menyediakan Al-Qur'an 30 juz yang dapat dibaca dan didengar sepenuhnya offline setelah unduhan.
- Menyediakan mode ulang yang fleksibel untuk menghafal.
- Menyediakan pilihan suara yang mudah diperluas tanpa merombak aplikasi.
- Memastikan seluruh konten memiliki dasar lisensi yang terdokumentasi.

### Metrik (target usulan, perlu disepakati)

| Metrik | Target usulan |
| --- | --- |
| Pengguna yang berhasil mengunduh minimal 1 juz setelah onboarding | ≥ 60% |
| Sesi yang memakai mode ulang | ≥ 40% |
| Sesi pemutaran yang berjalan tanpa internet | ≥ 70% |
| Aplikasi gagal (crash-free sessions) | ≥ 99% |
| Rating toko aplikasi | ≥ 4,5 |
| Ayat dengan ketidakcocokan teks-audio saat QA | 0 dari 6.236 |

## 4. Target Pengguna

| Persona | Kebutuhan utama |
| --- | --- |
| **Orang tua** (30-45 tahun) | Mengajari anak mengaji di rumah, memutar murottal berulang, antarmuka yang jelas |
| **Anak** (5-12 tahun, didampingi) | Tombol besar, mendengar bacaan dan mengulanginya |
| **Pelajar/penghafal dewasa** | Mengulang rentang ayat, melanjutkan hafalan, membaca dengan terjemahan |
| **Guru ngaji** | Alat bantu mengajar yang tidak bergantung pada sinyal |

## 5. Ruang Lingkup

### Termasuk dalam v1

- Teks Rasm Utsmani 30 juz dan 114 surah, riwayat Hafs 'an 'Asim
- Terjemahan Bahasa Indonesia per ayat
- Pemilihan suara saat awal pemakaian dan di Pengaturan
- Pemutar audio per ayat dengan sorotan ayat aktif
- Mode ulang (ayat, rentang, surah, juz, tanpa batas)
- Unduhan audio per juz dan per suara, dengan mode offline penuh
- Bookmark, Lanjutkan Terakhir, timer tidur, kecepatan putar
- Tema biru dan emas, mode gelap
- Halaman Tentang & Sumber

### Di luar v1

- Tafsir, tajwid berwarna, tebak ayat, dan fitur sosial
- Akun pengguna dan sinkronisasi antar-perangkat
- Iklan dan pembayaran dalam aplikasi
- Rekaman suara pengguna dan penilaian bacaan otomatis
- Qiraat selain Hafs

## 6. Alur Pengguna

```
Splash → Onboarding → Pilih Suara → Beranda (30 Juz / Surah)
→ Halaman Baca (Utsmani + Terjemahan) → Pemutar → Mode Ulang
                       ↘ Unduhan (per juz, per suara)
```

- **Splash:** logo TILAWAHKU di atas latar biru tua.
- **Onboarding:** 3 slide singkat (baca, dengar dan ulang, offline).
- **Pilih suara:** kartu Husary (muallim), Minshawi (anak mengulang), dan Anak Perempuan ("Segera hadir" bila belum tersedia). Setiap kartu punya tombol pratinjau.
- **Beranda:** daftar 30 juz, tab daftar surah, dan tombol "Lanjutkan Terakhir".
- **Unduh:** saat pengguna memilih juz yang audionya belum ada, aplikasi menawarkan unduhan dan menampilkan ukuran.
- **Baca dan putar:** teks Utsmani dengan terjemahan, ayat aktif disorot emas.
- **Ulang:** panel pengaturan pengulangan dari pemutar.

## 7. Kebutuhan Fungsional

Prioritas: **P0** wajib untuk rilis, **P1** penting, **P2** bila waktu memungkinkan.

### 7.1 Pemilihan suara

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-01 | Layar pilih suara muncul saat pertama kali dibuka | P0 |
| F-02 | Tiap suara punya pratinjau audio (misalnya Al-Fatihah) | P0 |
| F-03 | Pilihan tersimpan dan dapat diganti di Pengaturan kapan saja | P0 |
| F-04 | Daftar suara dibaca dari berkas konfigurasi (suara.json) sehingga suara baru ditambah tanpa mengubah kode | P0 |
| F-05 | Suara dengan status "segera hadir" tampil nonaktif dan tidak bisa dipilih | P1 |

### 7.2 Membaca

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-10 | Menampilkan teks Rasm Utsmani riwayat Hafs per ayat, tanpa mengubah teks sumber | P0 |
| F-11 | Menampilkan terjemahan Indonesia di bawah tiap ayat, dengan tombol tampil/sembunyi | P0 |
| F-12 | Navigasi per juz, per surah, dan per halaman | P0 |
| F-13 | Ukuran huruf Arab dan terjemahan dapat diatur | P1 |
| F-14 | Pencarian surah berdasarkan nama atau nomor | P1 |
| F-15 | Teks dan terjemahan dapat dibuka tanpa internet | P0 |

### 7.3 Pemutar audio

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-20 | Play, pause, ayat sebelumnya, ayat berikutnya | P0 |
| F-21 | Ayat yang sedang diputar disorot dan layar menggulir otomatis | P0 |
| F-22 | Audio berjalan di latar belakang dan dapat dikendalikan dari notifikasi serta layar kunci | P0 |
| F-23 | Kecepatan putar 0,75x sampai 1,5x | P1 |
| F-24 | Timer tidur (15, 30, 60 menit, akhir surah) | P1 |
| F-25 | Pemutaran dilanjutkan otomatis ke ayat atau surah berikutnya | P0 |

### 7.4 Mode ulang

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-30 | Ulang satu ayat sebanyak N kali (1-100) | P0 |
| F-31 | Ulang rentang ayat (dari ayat X sampai Y) sebanyak N kali | P0 |
| F-32 | Ulang satu surah atau satu juz | P0 |
| F-33 | Ulang tanpa batas | P0 |
| F-34 | Jeda antar-ulangan yang dapat diatur (0-10 detik) | P1 |
| F-35 | Indikator sisa pengulangan | P1 |

### 7.5 Unduhan dan offline

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-40 | Unduh audio per juz untuk suara yang dipilih | P0 |
| F-41 | Menampilkan ukuran, progres, jeda/lanjut, dan batal | P0 |
| F-42 | Hapus unduhan per juz dan per suara | P0 |
| F-43 | Peringatan bila ruang penyimpanan tidak cukup | P0 |
| F-44 | Setelah diunduh, pemutaran tidak memerlukan internet | P0 |
| F-45 | Opsi hanya-Wi-Fi untuk unduhan | P1 |
| F-46 | Pemeriksaan integritas berkas (jumlah file dan ukuran) setelah unduh | P1 |

### 7.6 Pendukung

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-50 | Bookmark ayat | P1 |
| F-51 | Lanjutkan Terakhir (surah, ayat, suara) | P0 |
| F-52 | Halaman Tentang & Sumber memuat atribusi teks, font, terjemahan, dan qari | P0 |
| F-53 | Mode gelap biru tua | P1 |

## 8. Kebutuhan Non-Fungsional

| Aspek | Kebutuhan |
| --- | --- |
| **Offline** | Semua fitur baca dan putar berjalan tanpa internet setelah paket diunduh. Internet hanya untuk mengunduh paket dan memperbarui konfigurasi. |
| **Ukuran awal** | Teks dan terjemahan dikemas dalam SQLite. Ukuran APK awal diupayakan kecil, dan audio tidak dibundel di dalam APK. |
| **Kinerja** | Halaman baca terbuka < 1 detik. Jeda antar-ayat tidak terdengar. |
| **Stabilitas** | Crash-free sessions ≥ 99%. |
| **Perangkat** | Android 8.0 ke atas, termasuk perangkat berspesifikasi rendah. |
| **Privasi** | Tidak ada akun dan tidak ada pelacakan identitas. Data bookmark dan progres disimpan lokal. Mengingat pengguna anak, patuhi kebijakan privasi anak dari Google Play dan App Store. |
| **Aksesibilitas** | Ukuran huruf dapat diperbesar, kontras tinggi, dan target sentuh minimal 48 dp. |
| **Akurasi konten** | Teks tidak boleh diubah atau dicampur dengan tulisan non-Qur'an. Seluruh 6.236 ayat harus cocok dengan audionya. |

## 9. Desain

### Palet warna

| Peran | Warna |
| --- | --- |
| Biru tua utama | #0B2A5B |
| Biru tua gelap (mode gelap) | #071B3D |
| Emas aksen | #C9A227 |
| Teks Arab | #F8F5EC |
| Terjemahan | #C9D3E6 |

### Prinsip tampilan

- Teks Arab berukuran besar dan lega, dengan penanda akhir ayat berwarna emas.
- Ayat yang sedang diputar disorot emas lembut.
- Mode anak: tombol besar, ikon sederhana, sedikit pilihan per layar.
- Font Arab: KFGQPC Hafs bila izin tertulis diperoleh. Bila belum, gunakan font Qur'an lain yang lisensinya mengizinkan penggunaan di aplikasi, dan baca lisensinya sebelum dipakai.

### Layar utama

Splash, Onboarding, Pilih Suara, Beranda (30 Juz / Surah), Halaman Baca, Pemutar dan Mode Ulang, Unduhan, Pengaturan, Tentang & Sumber.

## 10. Arsitektur dan Data

### 10.1 Prinsip

Data diambil **sekali** oleh skrip di komputer pengembang dari api.alquran.cloud, divalidasi, lalu dikemas. Aplikasi tidak memanggil API secara langsung untuk konten. Ini menjaga aplikasi tetap offline, menghindari batas permintaan, dan mengurangi beban pada layanan pihak ketiga.

### 10.2 Pipeline data

- **Daftar edisi:** periksa /v1/edition?format=audio dan /v1/edition?language=id untuk memastikan pengenal edisi yang benar (teks Utsmani, terjemahan Indonesia, audio Husary dan Minshawi).
- **Teks:** unduh edisi quran-uthmani.
- **Terjemahan:** unduh edisi terjemahan Indonesia yang terkonfirmasi dari daftar edisi.
- **Metadata:** juz, halaman, dan nomor ayat global (1-6236) dari respons.
- **Gabung:** hasilnya dibuat menjadi satu berkas SQLite.
- **Validasi:** hitung 6.236 ayat, cek acak terhadap mushaf cetak, dan cek tiap surah memiliki jumlah ayat yang benar.

### 10.3 Audio

- Audio per ayat diambil dengan pola CDN berdasarkan nomor ayat global dan pengenal edisi. Pola dan bitrate yang tersedia harus dipastikan lewat daftar edisi.
- Audio dikelompokkan menjadi **30 paket per suara**. Aplikasi mengunduh paket ke penyimpanan perangkat dan memutarnya secara lokal.
- Unduhan diberi jeda dan batas laju agar sesuai pemakaian wajar. Hasil unduhan disimpan sehingga tidak diunduh ulang.
- Bila file audio suatu suara berbentuk per surah, bukan per ayat, mode ulang per ayat memerlukan data waktu (timestamp) per ayat. Ini harus dipastikan sebelum suara tersebut diaktifkan.

### 10.4 Skema SQLite

```
surah(id, nama_ar, nama_id, jumlah_ayat)
ayah(nomor_global, surah, ayat, juz, halaman, teks_utsmani)
terjemah(nomor_global, teks_id)
suara(id, nama, gaya, status)
audio(nomor_global, suara_id, nama_file)
bookmark(nomor_global, dibuat_pada)
progres(suara_id, nomor_global, diperbarui_pada)
```

### 10.5 Konfigurasi suara

```json
{
  "suara": [
    {"id":"husary_muallim","nama":"Husary (Muallim)","status":"aktif"},
    {"id":"minshawi_muallim","nama":"Minshawi (Anak Mengulang)","status":"aktif"},
    {"id":"anak_perempuan","nama":"Anak Perempuan","status":"segera_hadir"}
  ]
}
```

Menambah suara berarti menambah entri dan paket audio, tanpa perubahan kode.

### 10.6 Teknologi

| Lapisan | Pilihan |
| --- | --- |
| Aplikasi | Flutter (Android dan iOS dari satu kode) |
| Basis data lokal | SQLite |
| Pemutar | just\_audio dan audio\_service |
| Unduhan | Manajer unduhan dengan fitur jeda dan lanjut |
| Penyimpanan konfigurasi | Berkas JSON lokal, diperbarui saat online |

## 11. Lisensi dan Kepatuhan

Aturan di bawah dirangkum dari syarat penyedia yang ditemukan saat riset. Syarat bisa berubah, jadi baca ulang sebelum rilis, dan minta tinjauan hukum untuk versi komersial.

| Komponen | Ketentuan yang diketahui | Tindakan |
| --- | --- | --- |
| **Teks Utsmani** | Layanan alquran.cloud mengizinkan penyimpanan dan penayangan teks untuk tujuan non-komersial, dan teks tidak boleh diubah atau dicampur dengan tulisan non-Qur'an | Rilis gratis. Cantumkan atribusi. Jangan ubah teks. |
| **Font KFGQPC** | Milik King Fahd Glorious Quran Printing Complex, dan perlu izin tertulis untuk reproduksi atau modifikasi | Kirim permohonan izin tertulis, atau pakai font berlisensi jelas |
| **Terjemahan Indonesia** | Sumber terjemahan Indonesia berasal dari Kemenag, dan penggunaan di luar non-komersial memerlukan izin penerjemah atau penerbit | Ajukan izin ke Kemenag bila akan dikomersialkan |
| **Audio** | Dilisensikan ke alquran.cloud untuk redistribusi gratis non-komersial. Boleh dimasukkan ke produk komersial, tetapi hak cipta tetap pada qari dan mereka dapat meminta penghapusan | Rilis gratis. Siapkan mekanisme untuk mengganti atau menghapus suara dengan cepat. |
| **Suara perempuan/anak perempuan** | Belum ditemukan set audio per ayat yang siap pakai dan jelas lisensinya | Rekam sendiri dengan kontrak tertulis, atau cari mitra berlisensi |

### Yang menjadi milik TILAWAHKU

Kode aplikasi, desain, nama dan logo, serta rekaman yang diproduksi sendiri dengan perjanjian tertulis. Teks Al-Qur'an, font, terjemahan, dan audio pihak lain tetap milik masing-masing pihak.

### Kewajiban

- Simpan semua syarat dan surat izin di dokumen internal.
- Tampilkan atribusi di halaman Tentang & Sumber.
- Jangan menjual atau memasang iklan pada versi v1 sebelum izin komersial jelas.
- Minta tashih dari lembaga yang kompeten sebelum rilis.

## 12. Risiko dan Mitigasi

| Risiko | Dampak | Mitigasi |
| --- | --- | --- |
| Edisi muallim tidak tersedia di alquran.cloud | Suara yang diinginkan tidak bisa dipakai | Periksa daftar edisi sejak awal. Siapkan sumber alternatif (misalnya EveryAyah) setelah lisensinya dicek, atau gunakan murottal biasa sementara. |
| Audio Minshawi berbentuk per surah | Mode ulang per ayat tidak berjalan | Pastikan format. Cari data waktu per ayat, atau batasi mode ulang untuk suara itu. |
| Qari meminta audionya dihapus | Suara hilang dari aplikasi | Konfigurasi suara jarak jauh, sehingga suara bisa dinonaktifkan tanpa rilis ulang. |
| Izin font atau terjemahan tidak diperoleh | Tidak bisa dirilis komersial | Rilis gratis, atau ganti font dan terjemahan dengan yang berlisensi jelas. |
| Layanan API berubah | Skrip pengambil data gagal | Data sudah dikemas lokal. Skrip hanya dijalankan saat pembaruan konten. |
| Ketidakcocokan teks dan audio | Kualitas bacaan menurun | Validasi otomatis dan uji acak oleh ahli tajwid. |
| Ukuran audio besar | Pengguna enggan mengunduh | Paket per juz, tampilkan ukuran, bitrate rendah, opsi Wi-Fi saja. |
| Suara perempuan tidak tersedia | Kategori kosong | Tampilkan "Segera hadir", rencanakan rekaman terpisah. |

## 13. Rencana dan Milestone

| Fase | Estimasi | Hasil |
| --- | --- | --- |
| 0. Persiapan dan lisensi | Minggu 1-2 | Nama dicek, edisi audio dikonfirmasi, permohonan izin terkirim |
| 1. Desain | Minggu 2-3 | Wireframe dan UI biru-emas disetujui |
| 2. Data | Minggu 3-5 | SQLite tervalidasi (6.236 ayat), paket audio per juz |
| 3. Pengembangan inti | Minggu 5-10 | Baca, pemutar, mode ulang, unduhan |
| 4. Pengujian | Minggu 10-12 | QA, uji offline, uji perangkat rendah, tashih |
| 5. Rilis beta | Minggu 12-13 | Uji tertutup dengan guru ngaji dan orang tua |
| 6. Rilis Google Play | Minggu 14 | v1.0 |
| 7. iOS dan suara baru | Setelah v1.0 | v1.1 dan suara perempuan bila siap |

Estimasi di atas bersifat usulan dan bergantung pada ukuran tim dan kecepatan izin.

## 14. Kriteria Penerimaan Rilis

- Seluruh 6.236 ayat tampil dengan teks dan terjemahan yang benar.
- Audio tiap ayat cocok dengan teksnya untuk semua suara yang aktif.
- Seluruh fitur P0 lulus pengujian, termasuk dalam mode pesawat setelah unduhan.
- Halaman Tentang & Sumber lengkap.
- Semua izin dan syarat lisensi tersimpan.
- Tashih telah dilakukan.

## 15. Pertanyaan Terbuka

- Apakah edisi muallim Husary dan Minshawi tersedia di api.alquran.cloud, dan dalam format apa (per ayat atau per surah)?
- Pengenal edisi terjemahan Indonesia yang tepat, dan apakah sumbernya Kemenag?
- Apakah pola unduhan per juz diizinkan oleh pengelola alquran.cloud?
- Font Arab apa yang akan dipakai, dan siapa yang mengurus izin KFGQPC?
- Siapa qari/qariah perempuan atau anak perempuan, dan bagaimana kontraknya?
- Apakah aplikasi akan tetap gratis selamanya, atau ada rencana komersial?
- Siapa lembaga yang akan melakukan tashih?
