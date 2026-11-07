import json
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "data" / "tilawahku_content.db"
OUTPUT = ROOT / "assets" / "data" / "quran_web_preview.json"


def main():
    with sqlite3.connect(SOURCE) as connection:
        surahs = connection.execute(
            "SELECT id, nama_ar, nama_id, jumlah_ayat FROM surah ORDER BY id"
        ).fetchall()
        ayahs = connection.execute(
            """
            SELECT ayah.nomor_global, ayah.surah, ayah.ayat, ayah.juz,
                   ayah.halaman, ayah.teks_utsmani, terjemah.teks_id,
                   transliterasi.teks_latin
            FROM ayah
            JOIN terjemah USING (nomor_global)
            JOIN transliterasi USING (nomor_global)
            ORDER BY ayah.nomor_global
            """
        ).fetchall()

    if len(surahs) != 114 or len(ayahs) != 6236:
        raise ValueError(
            f"Unexpected Quran content totals: {len(surahs)} surahs, "
            f"{len(ayahs)} ayahs"
        )

    OUTPUT.write_text(
        json.dumps(
            {"surahs": surahs, "ayahs": ayahs},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    print(f"Wrote {len(ayahs)} source ayahs to {OUTPUT}")


if __name__ == "__main__":
    main()
