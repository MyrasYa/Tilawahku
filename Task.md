# Task — TILAWAHKU

Rincian tugas per fase, diturunkan dari PRD TILAWAHKU v1.0 (23 Oktober 2026). Estimasi bersifat usulan dan bergantung pada ukuran tim dan kecepatan izin.

## Fase 0 — Persiapan dan Lisensi (Minggu 1–2)

- [ ] Cek ketersediaan nama "TILAWAHKU" (app store, domain, merek)
- [ ] Periksa `/v1/edition?format=audio` dan `/v1/edition?language=id` untuk konfirmasi edisi teks, terjemahan, dan audio Husary/Minshawi
- [ ] Kirim permohonan izin tertulis font KFGQPC
- [ ] Ajukan izin terjemahan Kemenag (bila akan dikomersialkan)
- [ ] Cari qari/qariah/suara anak perempuan dan susun kontrak rekaman (opsional, paralel)
- [ ] Dokumentasikan seluruh syarat lisensi yang ditemukan

## Fase 1 — Desain (Minggu 2–3)

- [ ] Buat wireframe seluruh layar (Splash, Onboarding, Pilih Suara, Beranda, Baca, Pemutar/Mode Ulang, Unduhan, Pengaturan, Tentang & Sumber)
- [ ] Terapkan palet biru tua dan emas, termasuk mode gelap
- [ ] Desain komponen kunci: kartu suara, baris ayat, mini-player, panel mode ulang, kartu unduhan
- [ ] Validasi desain mode anak (tombol besar, ikon sederhana)
- [ ] Review dan persetujuan UI oleh stakeholder

## Fase 2 — Data (Minggu 3–5)

- [ ] Tulis skrip pengambil data dari api.alquran.cloud (edisi teks, terjemahan, metadata)
- [ ] Unduh edisi `quran-uthmani`
- [ ] Unduh edisi terjemahan Indonesia terkonfirmasi
- [ ] Gabungkan data menjadi satu berkas SQLite sesuai skema (surah, ayah, terjemah, suara, audio, bookmark, progres)
- [ ] Validasi otomatis: hitung 6.236 ayat, cek acak terhadap mushaf cetak, cek jumlah ayat per surah
- [ ] Tentukan pola CDN audio per ayat dan susun paket audio per juz per suara (30 paket)
- [ ] Pastikan format audio Minshawi (per ayat vs per surah); siapkan data timestamp bila per surah
- [ ] Buat `suara.json` sesuai skema konfigurasi suara

## Fase 3 — Pengembangan Inti (Minggu 5–10)

### Pemilihan suara

- [ ] F-01–F-05: layar pilih suara, pratinjau audio, simpan pilihan, baca dari `suara.json`, status "segera hadir"

### Membaca

- [ ] F-10–F-15: render teks Utsmani, toggle terjemahan, navigasi juz/surah/halaman, ukuran huruf, pencarian surah, akses offline

### Pemutar audio

- [ ] F-20–F-25: kontrol play/pause/navigasi ayat, sorotan + auto-scroll, audio background + notifikasi/lock screen, kecepatan putar, timer tidur, auto-lanjut

### Mode ulang

- [ ] F-30–F-35: ulang 1 ayat (1–100x), ulang rentang ayat, ulang surah/juz, ulang tanpa batas, jeda antar-ulangan, indikator sisa pengulangan

### Unduhan dan offline

- [ ] F-40–F-46: unduh per juz/suara, progres & jeda/lanjut/batal, hapus unduhan, peringatan ruang penyimpanan, pemutaran offline penuh, opsi Wi-Fi saja, cek integritas berkas

### Pendukung

- [ ] F-50–F-53: bookmark ayat, Lanjutkan Terakhir, halaman Tentang & Sumber, mode gelap

## Fase 4 — Pengujian (Minggu 10–12)

- [ ] QA fungsional seluruh fitur P0 dan P1
- [ ] Uji mode offline penuh (mode pesawat setelah unduhan)
- [ ] Uji di perangkat berspesifikasi rendah (Android 8.0 ke atas)
- [ ] Validasi 6.236 ayat cocok dengan audio untuk tiap suara aktif
- [ ] Uji crash-free sessions (target ≥ 99%)
- [ ] Proses tashih oleh lembaga yang kompeten
- [ ] Review aksesibilitas (kontras, ukuran huruf, target sentuh 48 dp)

## Fase 5 — Rilis Beta (Minggu 12–13)

- [ ] Rekrut guru ngaji dan orang tua untuk uji tertutup
- [ ] Kumpulkan dan prioritaskan umpan balik
- [ ] Perbaikan bug dan penyesuaian berdasarkan hasil beta

## Fase 6 — Rilis Google Play (Minggu 14)

- [ ] Siapkan listing Google Play (deskripsi, tangkapan layar, kebijakan privasi anak)
- [ ] Pastikan kepatuhan kebijakan privasi anak Google Play
- [ ] Rilis v1.0
- [ ] Pantau crash report dan rating pasca-rilis

## Fase 7 — iOS dan Suara Baru (Setelah v1.0)

- [ ] Port/adaptasi ke iOS (v1.1)
- [ ] Kepatuhan kebijakan privasi anak App Store
- [ ] Integrasikan suara perempuan/anak perempuan bila rekaman dan lisensi siap
- [ ] Update `suara.json` dan paket audio tanpa perubahan kode

## Tugas Lintas-Fase (Berkelanjutan)

- [ ] Simpan seluruh syarat lisensi dan surat izin di dokumen internal
- [ ] Pantau perubahan syarat penyedia (alquran.cloud, Kemenag, KFGQPC)
- [ ] Siapkan mekanisme nonaktifkan suara dari jarak jauh (tanpa rilis ulang) jika qari meminta penghapusan
