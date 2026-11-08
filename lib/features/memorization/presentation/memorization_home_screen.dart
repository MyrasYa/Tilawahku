import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../reading/data/reading_repository.dart';
import '../data/memorization_repository.dart';
import '../domain/memorization_models.dart';
import 'memorization_program_detail_screen.dart';
import 'memorization_program_form_screen.dart';

class MemorizationHomeScreen extends StatefulWidget {
  const MemorizationHomeScreen({
    super.key,
    required this.repository,
    required this.readingRepository,
  });

  final MemorizationRepository repository;
  final ReadingRepository readingRepository;

  @override
  State<MemorizationHomeScreen> createState() => _MemorizationHomeScreenState();
}

class _MemorizationHomeScreenState extends State<MemorizationHomeScreen> {
  late Future<List<MemorizationProgram>> _programs;

  @override
  void initState() {
    super.initState();
    _programs = widget.repository.getPrograms();
  }

  Future<void> _reload() async {
    setState(() => _programs = widget.repository.getPrograms());
    await _programs;
  }

  Future<void> _createProgram() async {
    final created = await Navigator.of(context).push<MemorizationProgram>(
      MaterialPageRoute(
        builder: (_) => MemorizationProgramFormScreen(
          repository: widget.repository,
          readingRepository: widget.readingRepository,
        ),
      ),
    );
    if (!mounted || created == null) return;
    await _reload();
    if (!mounted) return;
    await _openProgram(created);
  }

  Future<void> _openProgram(MemorizationProgram program) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MemorizationProgramDetailScreen(
          programId: program.id,
          repository: widget.repository,
          readingRepository: widget.readingRepository,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hafalan Al-Qur’an')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _createProgram,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Program baru'),
    ),
    body: FutureBuilder<List<MemorizationProgram>>(
      future: _programs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.error_outline_rounded,
            message: 'Gagal memuat program hafalan.',
            detail: '${snapshot.error}',
            action: TextButton(
              onPressed: _reload,
              child: const Text('Coba lagi'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final programs = snapshot.data!;
        if (programs.isEmpty) {
          return _MessageState(
            icon: Icons.menu_book_outlined,
            message: 'Belum ada program hafalan.',
            detail:
                'Pilih surah, juz, atau rentang ayat untuk mulai menghafal.',
            action: FilledButton.icon(
              onPressed: _createProgram,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat program'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const Text(
                'Program hafalan tersimpan di perangkat dan dapat digunakan '
                'secara offline.',
              ),
              const SizedBox(height: 12),
              for (final program in programs)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.navy,
                      child: Icon(Icons.psychology_alt, color: AppColors.gold),
                    ),
                    title: Text(program.name),
                    subtitle: Text(
                      '${program.scope.label} · ${program.totalAyahs} ayat · '
                      'Target ${program.dailyTarget}/hari',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openProgram(program),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String message;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.gold),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
