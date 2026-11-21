import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../reading/data/reading_repository.dart';
import '../../reading/presentation/reading_screen.dart';
import '../data/memorization_repository.dart';
import '../domain/memorization_models.dart';
import 'memorization_history_screen.dart';
import 'memorization_practice_screen.dart';

class MemorizationProgramDetailScreen extends StatefulWidget {
  const MemorizationProgramDetailScreen({
    super.key,
    required this.programId,
    required this.repository,
    required this.readingRepository,
  });

  final String programId;
  final MemorizationRepository repository;
  final ReadingRepository readingRepository;

  @override
  State<MemorizationProgramDetailScreen> createState() =>
      _MemorizationProgramDetailScreenState();
}

class _MemorizationProgramDetailScreenState
    extends State<MemorizationProgramDetailScreen> {
  late Future<_ProgramDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<_ProgramDetails> _load() async {
    final program = await widget.repository.getProgram(widget.programId);
    if (program == null) throw StateError('Program hafalan tidak ditemukan.');
    final results = await Future.wait([
      widget.repository.getProgramAyahs(program),
      widget.repository.getProgress(program.id),
      widget.repository.getDailyProgress(program),
    ]);
    return _ProgramDetails(
      program,
      results[0] as List<AyahEntry>,
      results[1] as Map<int, MemorizationAyahProgress>,
      results[2] as DailyMemorizationProgress,
    );
  }

  Future<void> _refresh() async {
    setState(() => _details = _load());
    await _details;
  }

  Future<void> _startPractice(
    MemorizationProgram program,
    MemorizationSessionMode mode,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MemorizationPracticeScreen(
          program: program,
          repository: widget.repository,
          readingRepository: widget.readingRepository,
          initialMode: mode,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openReader(AyahEntry ayah) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.readingRepository,
          preferences: const _MemorizationReaderPreferences(),
          surahNumber: ayah.surahNumber,
          startingAyah: ayah.ayahNumber,
          saveReadingProgress: false,
          preserveExistingAudioQueue: true,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _confirmDelete(MemorizationProgram program) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus program?'),
        content: const Text(
          'Progres dan riwayat sesi pada program ini juga akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    await widget.repository.deleteProgram(program.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ProgramDetails>(
    future: _details,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Detail hafalan')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Gagal memuat program: ${snapshot.error}'),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: const Text('Detail hafalan')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      final details = snapshot.data!;
      final completedAyahs = details.progress.values
          .where((item) => item.status == MemorizationStatus.mastered)
          .length;
      final needsReview = details.progress.values
          .where((item) => item.status == MemorizationStatus.needsReview)
          .length;
      final nextAyah = details.ayahs.firstWhere(
        (ayah) =>
            details.progress[ayah.globalNumber]?.status !=
            MemorizationStatus.mastered,
        orElse: () => details.ayahs.first,
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(details.program.name),
          actions: [
            IconButton(
              tooltip: 'Hapus program',
              onPressed: () => _confirmDelete(details.program),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
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
                        '${details.program.scope.label} · '
                        '${details.program.totalAyahs} ayat',
                        style: const TextStyle(color: AppColors.parchment),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Target hari ini: '
                        '${details.dailyProgress.completedNewAyahs}/'
                        '${details.program.dailyTarget} ayat baru',
                        style: const TextStyle(
                          color: AppColors.parchment,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: details.dailyProgress.fraction,
                        color: AppColors.gold,
                        backgroundColor: AppColors.blue,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$completedAyahs/${details.program.totalAyahs} '
                        'dikuasai · $needsReview perlu diulang',
                        style: const TextStyle(color: AppColors.parchment),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _startPractice(
                  details.program,
                  MemorizationSessionMode.learn,
                ),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Mulai belajar'),
              ),
              OutlinedButton.icon(
                onPressed: () => _startPractice(
                  details.program,
                  MemorizationSessionMode.hideReveal,
                ),
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Sembunyikan & buka ayat'),
              ),
              OutlinedButton.icon(
                onPressed: () => _startPractice(
                  details.program,
                  MemorizationSessionMode.recall,
                ),
                icon: const Icon(Icons.psychology_alt_outlined),
                label: const Text('Latihan mengingat'),
              ),
              OutlinedButton.icon(
                onPressed: () => _startPractice(
                  details.program,
                  MemorizationSessionMode.audio,
                ),
                icon: const Icon(Icons.headphones_rounded),
                label: const Text('Pengulangan audio'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => MemorizationHistoryScreen(
                      program: details.program,
                      repository: widget.repository,
                      readingRepository: widget.readingRepository,
                    ),
                  ),
                ),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Riwayat dan perubahan status'),
              ),
              const SizedBox(height: 12),
              Text(
                'Ayat dalam program',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final ayah in details.ayahs)
                Card(
                  child: ListTile(
                    title: Text(
                      '${ayah.surahNameIndonesian ?? 'Surah ${ayah.surahNumber}'} '
                      '${ayah.surahNumber}:${ayah.ayahNumber}',
                    ),
                    subtitle: Text(
                      details.progress[ayah.globalNumber]?.status.label ??
                          MemorizationStatus.notStarted.label,
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => _openReader(ayah),
                  ),
                ),
              const SizedBox(height: 56),
              TextButton.icon(
                onPressed: () => _openReader(nextAyah),
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                label: const Text('Buka ayat berikutnya di Quran Reader'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ProgramDetails {
  const _ProgramDetails(
    this.program,
    this.ayahs,
    this.progress,
    this.dailyProgress,
  );

  final MemorizationProgram program;
  final List<AyahEntry> ayahs;
  final Map<int, MemorizationAyahProgress> progress;
  final DailyMemorizationProgress dailyProgress;
}

class _MemorizationReaderPreferences extends AppPreferences {
  const _MemorizationReaderPreferences();

  @override
  Future<String?> get selectedVoiceId async =>
      const AppPreferences().selectedVoiceId;
}
