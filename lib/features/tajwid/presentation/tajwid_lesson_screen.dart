import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../reading/data/reading_repository.dart';
import '../../reading/presentation/reading_screen.dart';
import '../domain/tajwid_models.dart';

class TajwidLessonScreen extends StatefulWidget {
  const TajwidLessonScreen({
    super.key,
    required this.lesson,
    required this.readingRepository,
  });

  final TajwidLesson lesson;
  final ReadingRepository readingRepository;

  @override
  State<TajwidLessonScreen> createState() => _TajwidLessonScreenState();
}

class _TajwidLessonScreenState extends State<TajwidLessonScreen> {
  late Future<List<AyahEntry?>> _examples;

  @override
  void initState() {
    super.initState();
    _examples = _loadExamples();
  }

  Future<List<AyahEntry?>> _loadExamples() async => Future.wait(
    widget.lesson.examples.map((example) async {
      final ayahs = await widget.readingRepository.getAyahsForSurah(
        example.surahNumber,
      );
      for (final ayah in ayahs) {
        if (ayah.ayahNumber == example.ayahNumber) return ayah;
      }
      return null;
    }),
  );

  Future<void> _openReader(AyahEntry ayah) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.readingRepository,
          preferences: const _TajwidReaderPreferences(),
          surahNumber: ayah.surahNumber,
          startingAyah: ayah.ayahNumber,
          saveReadingProgress: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.lesson.title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Chip(label: Text(widget.lesson.categoryId.title)),
        _LessonSection(title: 'Pengertian', body: widget.lesson.definition),
        _LessonSection(
          title: 'Kondisi terjadinya',
          body: widget.lesson.condition,
        ),
        _LessonSection(
          title: 'Cara membaca',
          body: widget.lesson.readingMethod,
        ),
        _LessonSection(
          title: 'Huruf yang berkaitan',
          body: widget.lesson.relatedLetters,
          arabic: _containsArabic(widget.lesson.relatedLetters),
        ),
        _LessonSection(
          title: 'Kesalahan yang perlu dihindari',
          body: widget.lesson.commonMistake,
        ),
        const SizedBox(height: 8),
        Text('Contoh dari ayat', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        FutureBuilder<List<AyahEntry?>>(
          future: _examples,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ExampleMessage(
                icon: Icons.error_outline_rounded,
                message: 'Contoh ayat gagal dimuat dari penyimpanan lokal.',
                detail: '${snapshot.error}',
                onRetry: () => setState(() => _examples = _loadExamples()),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return Column(
              children: [
                for (
                  var index = 0;
                  index < widget.lesson.examples.length;
                  index++
                )
                  _ExampleCard(
                    reference: widget.lesson.examples[index],
                    ayah: snapshot.data![index],
                    onOpenReader: snapshot.data![index] == null
                        ? null
                        : () => _openReader(snapshot.data![index]!),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text('Rujukan materi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final reference in widget.lesson.references)
          Card(
            child: ListTile(
              leading: const Icon(Icons.library_books_outlined),
              title: Text(reference.title),
              subtitle: Text('${reference.section}\n${reference.url}'),
              isThreeLine: true,
            ),
          ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Catatan penandaan'),
            subtitle: Text(
              'Teks ayat ditampilkan apa adanya dari data lokal. Tidak ada '
              'warna hukum tajwid atau deteksi otomatis karena anotasi '
              'terverifikasi belum tersedia.',
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

bool _containsArabic(String value) =>
    value.runes.any((rune) => rune >= 0x0600 && rune <= 0x06FF);

class _LessonSection extends StatelessWidget {
  const _LessonSection({
    required this.title,
    required this.body,
    this.arabic = false,
  });

  final String title;
  final String body;
  final bool arabic;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            body,
            textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            textAlign: arabic ? TextAlign.right : TextAlign.start,
            style: arabic
                ? const TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 20,
                    height: 1.7,
                  )
                : null,
          ),
        ],
      ),
    ),
  );
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.reference,
    required this.ayah,
    required this.onOpenReader,
  });

  final TajwidAyahReference reference;
  final AyahEntry? ayah;
  final VoidCallback? onOpenReader;

  @override
  Widget build(BuildContext context) {
    final entry = ayah;
    if (entry == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded),
          title: Text('Surah ${reference.surahNumber}:${reference.ayahNumber}'),
          subtitle: const Text('Ayat contoh tidak ditemukan di data lokal.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${entry.surahNameIndonesian ?? 'Surah ${entry.surahNumber}'} '
              '${entry.surahNumber}:${entry.ayahNumber}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Text(
              entry.uthmaniText,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 26,
                height: 1.9,
              ),
            ),
            if (entry.indonesianTranslation case final translation?
                when translation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(translation, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 8),
            Text(reference.note),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const ValueKey('tajwid-open-reader'),
                onPressed: onOpenReader,
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                label: const Text('Buka di Quran Reader'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleMessage extends StatelessWidget {
  const _ExampleMessage({
    required this.icon,
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(message),
      subtitle: Text(detail),
      trailing: IconButton(
        tooltip: 'Coba lagi',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ),
  );
}

class _TajwidReaderPreferences extends AppPreferences {
  const _TajwidReaderPreferences();

  @override
  Future<String?> get selectedVoiceId async =>
      const AppPreferences().selectedVoiceId;
}
