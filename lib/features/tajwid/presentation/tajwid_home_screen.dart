import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../reading/data/reading_repository.dart';
import '../data/tajwid_repository.dart';
import '../domain/tajwid_models.dart';
import 'tajwid_lesson_screen.dart';
import 'tajwid_quiz_screen.dart';

class TajwidHomeScreen extends StatefulWidget {
  const TajwidHomeScreen({
    super.key,
    required this.repository,
    required this.readingRepository,
  });

  final TajwidRepository repository;
  final ReadingRepository readingRepository;

  @override
  State<TajwidHomeScreen> createState() => _TajwidHomeScreenState();
}

class _TajwidHomeScreenState extends State<TajwidHomeScreen> {
  late Future<TajwidQuizProgress> _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.repository.getProgress();
  }

  void _reloadProgress() {
    setState(() => _progress = widget.repository.getProgress());
  }

  Future<void> _openQuiz() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TajwidQuizScreen(repository: widget.repository),
      ),
    );
    if (mounted) _reloadProgress();
  }

  Future<void> _openLesson(TajwidLesson lesson) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TajwidLessonScreen(
          lesson: lesson,
          readingRepository: widget.readingRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Belajar Tajwid')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          color: AppColors.navy,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belajar hukum bacaan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.parchment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Materi dan contoh ayat tersedia offline. Baca ringkasan, '
                  'lalu buka ayat sumber di Quran Reader.',
                  style: TextStyle(color: AppColors.parchment),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _openQuiz,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Mulai latihan'),
                ),
                const SizedBox(height: 10),
                FutureBuilder<TajwidQuizProgress>(
                  future: _progress,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Progres latihan tidak dapat dimuat.',
                              style: TextStyle(color: AppColors.parchment),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Muat ulang progres',
                            onPressed: _reloadProgress,
                            color: AppColors.parchment,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final progress = snapshot.data!;
                    return Text(
                      progress.completedAttempts == 0
                          ? 'Belum ada latihan tersimpan.'
                          : 'Latihan selesai: ${progress.completedAttempts} · '
                                'Skor terbaik: '
                                '${(progress.bestScoreFraction * 100).round()}%',
                      style: const TextStyle(color: AppColors.parchment),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _ScopeNotice(),
        const SizedBox(height: 16),
        Text('Kategori materi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final category in widget.repository.getCategories())
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(category.id.title),
              subtitle: Text(category.description),
              children: [
                for (final lesson in widget.repository.getLessons(category.id))
                  ListTile(
                    title: Text(lesson.title),
                    subtitle: Text(lesson.definition),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openLesson(lesson),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        'Materi ini adalah pengantar, bukan evaluasi pelafalan. Penandaan '
        'warna otomatis belum tersedia karena data anotasi ayat yang '
        'terverifikasi belum menjadi bagian dari aplikasi. Untuk rincian '
        'bacaan, belajar dan talaqqi bersama guru.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}
