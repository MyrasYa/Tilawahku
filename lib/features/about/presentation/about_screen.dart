import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tentang & Sumber')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Image.asset(
            'assets/branding/tilawahku_icon.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'TILAWAHKU',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 20),
        _SourceItem(
          title: 'Teks Al-Qur’an',
          detail:
              'Teks Arab yang ditampilkan memakai edisi Utsmani dari '
              'AlQuran.cloud. Sumber teksnya adalah Tanzil.net dan Quran '
              'Academy. Teks disimpan apa adanya.',
        ),
        _SourceItem(
          title: 'Transliterasi Latin',
          detail:
              'Transliterasi bacaan ayat menggunakan edisi '
              'en.transliteration dari AlQuran.cloud.',
        ),
        _SourceItem(
          title: 'Terjemahan Indonesia',
          detail:
              'Arti ayat menggunakan edisi bahasa Indonesia '
              'id.indonesian dari AlQuran.cloud. Atribusi terjemahan: '
              'Kementerian Agama Republik Indonesia.',
        ),
        _SourceItem(
          title: 'Audio bacaan',
          detail:
              'Pilihan qari mencakup Mahmoud Khalil Al-Husary, Mohamed '
              'Siddiq Al-Minshawi, Mishary Rashid Alafasy, Muhammad '
              'Al-Luhaidan, Abdul Basit '
              'Abdus-Samad, Abdurrahmaan As-Sudais, Hani Rifai, Maher Al '
              'Muaiqly, Muhammad Ayyoub, dan Saood bin Ibraaheem '
              'Ash-Shuraym. Edition ID berasal dari katalog audio '
              'AlQuran.cloud; audio per ayat disajikan melalui Islamic '
              'Network CDN. Muhammad Al-Luhaidan memakai streaming audio '
              'per surah; repeat ayat/rentang dan unduhan offline belum '
              'tersedia untuknya. Lisensi khusus rekaman Luhaidan belum '
              'terverifikasi. Audio yang telah diunduh untuk qari per ayat '
              'dapat diputar kembali tanpa internet.',
        ),
        _SourceItem(
          title: 'Privasi',
          detail:
              'Pengaturan dan progres bacaan disimpan di perangkat. '
              'Tilawahku tidak memerlukan akun.',
        ),
      ],
    ),
  );
}

class _SourceItem extends StatelessWidget {
  const _SourceItem({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(detail),
        ],
      ),
    ),
  );
}
