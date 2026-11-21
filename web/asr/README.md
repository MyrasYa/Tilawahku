# `web/asr/` — berkas rilis model ASR Web

Runtime ASR Web (`AsrModelTransportWeb`) mengambil berkas model relatif terhadap
`Uri.base`, yaitu `asr/<nama>` di akar situs. Direktori ini adalah satu-satunya
tempat berkas tersebut disajikan.

| Berkas | Ukuran | Status Git | Keterangan |
| --- | --- | --- | --- |
| `model.int8.onnx` | 36 081 762 B | **diabaikan** | Bobot INT8 Zipformer CTC. Terlalu besar untuk bundel Git dan tidak boleh masuk `flutter_assets`. |
| `tokens.txt` | 180 B | dilacak | Daftar token yang dipakai konfigurasi engine. |
| `LICENSE` | 1 062 B | dilacak | MIT, hak cipta 2026 Abdou (`Abdou/quran-asr-small`). Ikut disajikan bersama bobotnya. |

Identitas rilis (nama, ukuran, SHA-256) dikunci di
`lib/features/assessment/data/asr_model_release.dart` dan dipakai sebagai acuan
verifikasi di bawah.

## Mendapatkan bobot model

Bobot tidak diunduh otomatis oleh tool dan URL hosting-nya **belum dibakukan di
repo ini** — penentuannya adalah tugas pemilik rilis. Letakkan
`model.int8.onnx` hasil unduhan dari sumber rilis yang disepakati ke direktori
ini, lalu cocokkan SHA-256-nya terhadap `asrWebModelRelease.model.sha256Hex`.
Berkas dengan hash yang berbeda tidak boleh dipakai; tool staging menolaknya.

## Membangun situs yang siap disajikan

`flutter build web` menyalin isi `web/` apa adanya, jadi di mesin kerja
yang cache-nya lengkap hasil build sudah berisi `asr/`. Di mesin bersih
(fresh clone, CI) bobotnya tidak ada karena diabaikan Git, sehingga staging
menjadi langkah wajib setelah build:

```sh
flutter build web --release
dart run tool/stage_web_asr_model.dart --out build/web
```

Tool tersebut, per berkas:

1. melewati target yang sudah cocok ukuran **dan** SHA-256-nya;
2. membaca kandidat dari `--source` (bawaan `web/asr`) lalu dari
   `--base-url` / environment `ASR_MODEL_BASE_URL` bila cache lokal tidak
   lengkap;
3. menolak menulis berkas yang ukuran atau SHA-256-nya tidak cocok dengan
   rilis;
4. menulis lewat `*.part` lalu mengganti namanya, sehingga hasil unduhan yang
   terpotong tidak pernah tampak sebagai model yang sah.

Ia keluar dengan kode 0 hanya bila seluruh berkas rilis terverifikasi.

Untuk harness lokal, stage ke bundle probe juga:

```sh
dart run tool/stage_web_asr_model.dart --out build/web --out build/web_probe
```

## Yang tidak dilakukan staging

`ASR_MODEL_BASE_URL` hanyalah **sumber** untuk staging. Waktu berjalan,
transport Web selalu `fetch` same-origin ke `asr/<nama>`, jadi bobot harus ikut
terhidangkan sebagai berkas statis di samping hasil build — bukan diarahkan ke
host lain.
