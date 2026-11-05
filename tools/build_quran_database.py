#!/usr/bin/env python3
"""Build the bundled, read-only Quran text and audio manifest database."""

from __future__ import annotations

import json
import sqlite3
import time
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
VOICE_CATALOG = ROOT / "assets" / "config" / "suara.json"
OUTPUT = ROOT / "assets" / "data" / "tilawahku_content.db"
ARABIC_EDITION = "quran-uthmani"
TRANSLATION_EDITION = "id.indonesian"
TRANSLITERATION_EDITION = "en.transliteration"
EXPECTED_SURAHS = 114
EXPECTED_AYAHS = 6236
API_BASE = "https://api.alquran.cloud/v1/quran"

SCHEMA = (
    """
    CREATE TABLE surah (
      id INTEGER PRIMARY KEY,
      nama_ar TEXT NOT NULL,
      nama_id TEXT NOT NULL,
      jumlah_ayat INTEGER NOT NULL CHECK (jumlah_ayat > 0)
    )
    """,
    """
    CREATE TABLE ayah (
      nomor_global INTEGER PRIMARY KEY,
      surah INTEGER NOT NULL,
      ayat INTEGER NOT NULL,
      juz INTEGER NOT NULL,
      halaman INTEGER NOT NULL,
      teks_utsmani TEXT NOT NULL,
      FOREIGN KEY (surah) REFERENCES surah (id),
      UNIQUE (surah, ayat)
    )
    """,
    """
    CREATE TABLE terjemah (
      nomor_global INTEGER PRIMARY KEY,
      teks_id TEXT NOT NULL,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
        ON DELETE CASCADE
    )
    """,
    """
    CREATE TABLE transliterasi (
      nomor_global INTEGER PRIMARY KEY,
      teks_latin TEXT NOT NULL,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
        ON DELETE CASCADE
    )
    """,
    """
    CREATE TABLE suara (
      id TEXT PRIMARY KEY,
      nama TEXT NOT NULL,
      gaya TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('aktif', 'segera_hadir', 'nonaktif'))
    )
    """,
    """
    CREATE TABLE audio (
      nomor_global INTEGER NOT NULL,
      suara_id TEXT NOT NULL,
      nama_file TEXT NOT NULL,
      PRIMARY KEY (nomor_global, suara_id),
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
        ON DELETE CASCADE,
      FOREIGN KEY (suara_id) REFERENCES suara (id)
        ON DELETE CASCADE
    )
    """,
    """
    CREATE TABLE bookmark (
      nomor_global INTEGER PRIMARY KEY,
      dibuat_pada TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
        ON DELETE CASCADE
    )
    """,
    """
    CREATE TABLE progres (
      suara_id TEXT PRIMARY KEY,
      nomor_global INTEGER NOT NULL,
      diperbarui_pada TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (suara_id) REFERENCES suara (id),
      FOREIGN KEY (nomor_global) REFERENCES ayah (nomor_global)
    )
    """,
    """
    CREATE TABLE audio_package (
      suara_id TEXT NOT NULL,
      juz INTEGER NOT NULL CHECK (juz BETWEEN 1 AND 30),
      status TEXT NOT NULL DEFAULT 'not_downloaded'
        CHECK (status IN (
          'not_downloaded', 'queued', 'downloading', 'paused',
          'failed', 'complete'
        )),
      total_ayah INTEGER NOT NULL CHECK (total_ayah > 0),
      downloaded_ayah INTEGER NOT NULL DEFAULT 0,
      total_bytes INTEGER NOT NULL DEFAULT 0,
      downloaded_bytes INTEGER NOT NULL DEFAULT 0,
      error TEXT,
      diperbarui_pada TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (suara_id, juz),
      FOREIGN KEY (suara_id) REFERENCES suara (id) ON DELETE CASCADE
    )
    """,
    """
    CREATE TABLE content_metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    """,
)

INDEXES = (
    "CREATE INDEX ayah_surah_ayat_idx ON ayah (surah, ayat)",
    "CREATE INDEX ayah_juz_nomor_idx ON ayah (juz, nomor_global)",
    "CREATE INDEX ayah_halaman_nomor_idx ON ayah (halaman, nomor_global)",
)


def fetch_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Tilawahku-Offline-Data-Builder/1.0"},
    )
    last_error: Exception | None = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                payload = json.load(response)
            if payload.get("code") != 200 or payload.get("status") != "OK":
                raise ValueError(f"Source returned an unsuccessful response: {url}")
            return payload["data"]
        except (OSError, urllib.error.URLError, ValueError, KeyError) as error:
            last_error = error
            if attempt == 4:
                break
            time.sleep(2**attempt)
    raise RuntimeError(f"Could not fetch Quran edition {url}") from last_error


def flatten_surahs(
    data: dict[str, Any], edition_id: str
) -> tuple[list[dict[str, Any]], dict[int, dict[str, Any]]]:
    surahs = data.get("surahs")
    if not isinstance(surahs, list) or len(surahs) != EXPECTED_SURAHS:
        raise ValueError(f"{edition_id}: expected {EXPECTED_SURAHS} surahs")

    ayahs: list[dict[str, Any]] = []
    metadata: dict[int, dict[str, Any]] = {}
    for expected_surah, surah in enumerate(surahs, start=1):
        surah_number = surah.get("number")
        entries = surah.get("ayahs")
        if surah_number != expected_surah or not isinstance(entries, list):
            raise ValueError(f"{edition_id}: invalid surah ordering")
        metadata[surah_number] = {
            "arabic_name": surah["name"],
            "indonesian_name": surah.get("englishName", ""),
            "ayah_count": len(entries),
        }
        for expected_ayah, ayah in enumerate(entries, start=1):
            if ayah.get("numberInSurah") != expected_ayah:
                raise ValueError(f"{edition_id}: invalid ayah order in surah {surah_number}")
            ayahs.append({**ayah, "_surah_number": surah_number})
    return ayahs, metadata


def build_database() -> None:
    voices_document = json.loads(VOICE_CATALOG.read_text(encoding="utf-8"))
    voices = [
        voice for voice in voices_document["suara"] if voice["status"] == "aktif"
    ]
    if not voices:
        raise ValueError("The local voice catalog has no active reciters.")

    arabic_data = fetch_json(f"{API_BASE}/{ARABIC_EDITION}")
    time.sleep(1.1)
    translation_data = fetch_json(f"{API_BASE}/{TRANSLATION_EDITION}")
    time.sleep(1.1)
    transliteration_data = fetch_json(f"{API_BASE}/{TRANSLITERATION_EDITION}")

    arabic_ayahs, surah_metadata = flatten_surahs(arabic_data, ARABIC_EDITION)
    translation_ayahs, translation_metadata = flatten_surahs(
        translation_data, TRANSLATION_EDITION
    )
    transliteration_ayahs, _ = flatten_surahs(
        transliteration_data, TRANSLITERATION_EDITION
    )
    if len(arabic_ayahs) != EXPECTED_AYAHS:
        raise ValueError(f"Arabic edition has {len(arabic_ayahs)} ayahs")
    if len(translation_ayahs) != EXPECTED_AYAHS:
        raise ValueError(
            f"Translation edition has {len(translation_ayahs)} ayahs"
        )
    if len(transliteration_ayahs) != EXPECTED_AYAHS:
        raise ValueError(
            f"Transliteration edition has {len(transliteration_ayahs)} ayahs"
        )

    translations = {ayah["number"]: ayah["text"] for ayah in translation_ayahs}
    transliterations = {
        ayah["number"]: ayah["text"] for ayah in transliteration_ayahs
    }
    if set(translations) != set(range(1, EXPECTED_AYAHS + 1)):
        raise ValueError("Translation global ayah numbers are incomplete or duplicated.")
    if (
        set(transliterations) != set(range(1, EXPECTED_AYAHS + 1))
        or any(
            not isinstance(text, str) or not text.strip()
            for text in transliterations.values()
        )
    ):
        raise ValueError(
            "Transliteration global ayah numbers are incomplete or duplicated."
        )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    temporary_output = OUTPUT.with_suffix(".db.tmp")
    if temporary_output.exists():
        temporary_output.unlink()
    db = sqlite3.connect(temporary_output)
    try:
        db.execute("PRAGMA foreign_keys = ON")
        for statement in SCHEMA:
            db.execute(statement)
        for statement in INDEXES:
            db.execute(statement)

        for number, data in surah_metadata.items():
            translated_surah = translation_metadata[number]
            if data["ayah_count"] != translated_surah["ayah_count"]:
                raise ValueError(f"Surah {number}: source ayah counts do not match")
            db.execute(
                "INSERT INTO surah (id, nama_ar, nama_id, jumlah_ayat) "
                "VALUES (?, ?, ?, ?)",
                (
                    number,
                    data["arabic_name"],
                    data["indonesian_name"],
                    data["ayah_count"],
                ),
            )

        for voice in voices:
            db.execute(
                "INSERT INTO suara (id, nama, gaya, status) VALUES (?, ?, ?, ?)",
                (voice["id"], voice["nama"], voice["gaya"], voice["status"]),
            )

        counts_by_juz: Counter[tuple[str, int]] = Counter()
        for ayah in arabic_ayahs:
            global_number = ayah.get("number")
            surah_number = ayah.get("_surah_number")
            verse_number = ayah.get("numberInSurah")
            juz = ayah.get("juz")
            page = ayah.get("page")
            arabic_text = ayah.get("text")
            if (
                not isinstance(global_number, int)
                or not isinstance(surah_number, int)
                or not isinstance(verse_number, int)
                or not isinstance(juz, int)
                or not isinstance(page, int)
                or not isinstance(arabic_text, str)
                or global_number not in translations
            ):
                raise ValueError(f"Invalid Arabic ayah record: {global_number}")

            db.execute(
                """
                INSERT INTO ayah
                  (nomor_global, surah, ayat, juz, halaman, teks_utsmani)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (global_number, surah_number, verse_number, juz, page, arabic_text),
            )
            db.execute(
                "INSERT INTO terjemah (nomor_global, teks_id) VALUES (?, ?)",
                (global_number, translations[global_number]),
            )
            db.execute(
                "INSERT INTO transliterasi (nomor_global, teks_latin) "
                "VALUES (?, ?)",
                (global_number, transliterations[global_number]),
            )
            for voice in voices:
                db.execute(
                    "INSERT INTO audio (nomor_global, suara_id, nama_file) "
                    "VALUES (?, ?, ?)",
                    (
                        global_number,
                        voice["id"],
                        f"{global_number:06d}.mp3",
                    ),
                )
                counts_by_juz[(voice["id"], juz)] += 1

        if db.execute("SELECT COUNT(*) FROM ayah").fetchone()[0] != EXPECTED_AYAHS:
            raise ValueError("Built database does not contain exactly 6,236 ayahs.")
        for voice in voices:
            for juz in range(1, 31):
                count = counts_by_juz.get((voice["id"], juz), 0)
                if count == 0:
                    raise ValueError(f"Missing audio manifest: {voice['id']} juz {juz}")
                db.execute(
                    "INSERT INTO audio_package (suara_id, juz, total_ayah) "
                    "VALUES (?, ?, ?)",
                    (voice["id"], juz, count),
                )

        violations = db.execute("PRAGMA foreign_key_check").fetchall()
        if violations:
            raise ValueError(f"Database has foreign-key violations: {violations[:3]}")
        db.execute("PRAGMA user_version = 4")
        db.executemany(
            "INSERT INTO content_metadata (key, value) VALUES (?, ?)",
            [
                ("arabic_edition", ARABIC_EDITION),
                ("translation_edition", TRANSLATION_EDITION),
                ("transliteration_edition", TRANSLITERATION_EDITION),
                ("arabic_source", "AlQuran.cloud; source attribution: Tanzil.net and Quran Academy"),
                ("translation_attribution", "AlQuran.cloud id.indonesian; translator attribution in API metadata: Unknown"),
                ("audio_source", "AlQuran.cloud / Islamic Network CDN"),
                ("built_at_utc", datetime.now(timezone.utc).isoformat()),
                ("ayah_count", str(EXPECTED_AYAHS)),
            ],
        )
        db.commit()
    finally:
        db.close()

    temporary_output.replace(OUTPUT)
    print(
        f"Built {OUTPUT.relative_to(ROOT)}: 114 surahs, 6,236 ayahs, "
        f"{len(voices)} voices, {len(voices) * 30} audio package manifests."
    )


if __name__ == "__main__":
    build_database()
