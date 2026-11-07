# TILAWAHKU

TILAWAHKU is an offline-first Qur'an reader and recitation app built with
Flutter. Qur'an text and Indonesian translation are bundled in SQLite; reciter
audio is downloaded per ayah and stored on the device, not included in the APK.
The downloads screen groups audio progress and storage use by juz.

## Project structure

- `lib/app/` — application bootstrap and centralized light/dark themes.
- `lib/core/database/` — SQLite schema, migration, and bundled database copy.
- `lib/core/preferences/` — onboarding and local preferences.
- `lib/features/reading/` — home, page and surah reader, scroll-saved reading
  progress, bookmark management, and content repository.
- `lib/features/voices/` — local voice catalog and voice selection.
- `lib/features/player/` — local audio repository, background playback, and
  repeat/player screens.
- `lib/features/repeat/` — repeat settings for ayah, range, surah, juz, or queue.
- `lib/features/download/` — per-ayah and per-juz audio download manager and
  juz summary screen.
- `lib/features/settings/` — accessibility, theme, and application settings.
- `lib/features/about/` — source and attribution information.
- `assets/config/suara.json` — voice catalogue and CDN edition identifiers.
- `assets/data/tilawahku_content.db` — bundled text, translation, and audio
  manifests.
- `assets/fonts/` — Amiri Quran font and its SIL Open Font License.
- `tools/build_quran_database.py` — offline-database build/import script.

## Bundled content and provenance

The checked-in database contains 114 surahs and 6,236 ayahs with the
`quran-uthmani` Arabic edition, `id.indonesian` translation, and
`en.transliteration` transliteration from AlQuran.cloud. It also contains three
per-ayah audio manifests (Husary,
Minshawi, and Alafasy) with 30 juz packages per reciter. The manifest only
stores filenames and CDN metadata; MP3 files are not bundled. Audio is downloaded automatically
when an ayah is first played, or a juz or surah can be downloaded from the
downloads screen for offline use.

The `id.indonesian` API edition metadata currently identifies its translator as
`Unknown`. Therefore this database must not be represented as a verified
Kementerian Agama edition unless the exact text is matched against the
authorized Kemenag source. The app owner has stated that written permission is
available, but the permission and dataset-to-edition match are not verified by
this repository. Confirm those before distribution.

The Latin transliteration is displayed below each Arabic ayah and comes from
AlQuran.cloud's `en.transliteration` edition.

The Arabic reader uses Amiri Quran from Google Fonts, a Quran-focused font
distributed under the SIL Open Font License 1.1; the license is included in
`assets/fonts/OFL.txt`.

Arabic edition and source information, the translation edition, audio source,
and build timestamp are stored in `content_metadata`. Review source terms and
include the required attribution when distributing the app. Audio can be
withdrawn by its rights holder; the current voice catalogue is local and does
not yet provide remote revocation.

The build script downloads content only when explicitly run; the app itself
does not call AlQuran.cloud at runtime. Rebuild the database after reviewing
the source editions and applicable permissions:

```shell
python tools/build_quran_database.py
```

The importer checks the surah and ayah totals, source ordering, translation
coverage, audio manifest completeness, and SQLite foreign keys before
replacing the bundled database.

## Run and verify

```shell
flutter pub get
flutter run
flutter analyze
flutter test
```

Background audio uses `just_audio` and `audio_service`. The Android activity
and manifest are configured for background playback and system media controls.

## Flutter Web preview

The browser preview uses the experimental `sqflite_common_ffi_web` SQLite
driver, which stores its database in IndexedDB. After `flutter pub get`, install
the driver's WebAssembly and worker files into `web/`:

```shell
dart run sqflite_common_ffi_web:setup
flutter run -d chrome
```

The Web database is initialized from `assets/data/quran_web_preview.json`.
That fixture is generated from the project's bundled SQLite content with
`python tools/build_quran_web_preview.py`; it contains the same 114 surahs and
6,236 ayahs, translations, and transliterations. Bookmarks and reading
preferences are stored by the browser's SQLite/IndexedDB and
SharedPreferences/Web implementations, respectively. Web preview does not
enable audio playback or audio downloads; it displays this limitation instead
of claiming that audio is stored locally.

## Current operational limitations

- Text and translation are available offline from the bundled database.
- Audio is available offline after its ayah has been downloaded to the device.
- Downloading requires internet access and sufficient storage.
- The audio downloads screen summarizes downloaded ayahs and storage use per
  juz or surah. Users can download a whole juz or surah, pause or resume
  downloads, and delete audio by juz or surah. Since both groupings reference
  the same per-ayah files, deleting one group also removes those ayahs from
  overlapping downloads in the other grouping.
- Choosing a different reciter offers an optional download of one selected juz.
  Additional juz are downloaded individually from the downloads screen.
- On upgrade, the app now seeds missing Qur'an text and audio manifests from
  the bundled database while retaining existing bookmark and progress rows.
- The source API does not identify the `id.indonesian` translator by name.
- Remote voice revocation and verification of the exact Kemenag translation
  edition remain outstanding.
