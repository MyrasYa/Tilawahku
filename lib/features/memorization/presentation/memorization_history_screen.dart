import 'package:flutter/material.dart';

import '../../reading/data/reading_repository.dart';
import '../../reading/presentation/reading_screen.dart';
import '../../../core/preferences/app_preferences.dart';
import '../data/memorization_repository.dart';
import '../domain/memorization_models.dart';

class MemorizationHistoryScreen extends StatefulWidget {
  const MemorizationHistoryScreen({
    super.key,
    required this.program,
    required this.repository,
    required this.readingRepository,
  });

  final MemorizationProgram program;
  final MemorizationRepository repository;
  final ReadingRepository readingRepository;

  @override
  State<MemorizationHistoryScreen> createState() =>
      _MemorizationHistoryScreenState();
}

class _MemorizationHistoryScreenState extends State<MemorizationHistoryScreen> {
  late Future<_HistoryData> _history;

  @override
  void initState() {
    super.initState();
    _history = _load();
  }

  Future<_HistoryData> _load() async {
    final results = await Future.wait([
      widget.repository.getSessions(widget.program.id),
      widget.repository.getStatusHistory(widget.program.id),
    ]);
    return _HistoryData(
      results[0] as List<MemorizationSession>,
      results[1] as List<MemorizationStatusChange>,
    );
  }

  Future<void> _openAyah(int globalAyahNumber) async {
    final ayah = (await widget.repository.getProgramAyahs(
      widget.program,
    )).firstWhere((item) => item.globalNumber == globalAyahNumber);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.readingRepository,
          preferences: const _HistoryReaderPreferences(),
          surahNumber: ayah.surahNumber,
          startingAyah: ayah.ayahNumber,
          saveReadingProgress: false,
          preserveExistingAudioQueue: true,
        ),
      ),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat hafalan')),
    body: FutureBuilder<_HistoryData>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Gagal memuat riwayat: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.sessions.isEmpty && data.changes.isEmpty) {
          return const Center(child: Text('Belum ada riwayat hafalan.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (data.sessions.isNotEmpty) ...[
              Text(
                'Sesi latihan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final session in data.sessions)
                _SessionTile(
                  session: session,
                  dateLabel: _formatDate(session.startedAt),
                  onLoadAyahs: () =>
                      widget.repository.getSessionAyahs(session.id),
                  onOpenAyah: _openAyah,
                ),
            ],
            if (data.changes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Perubahan status ayat',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final change in data.changes)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: Text(
                      '${change.oldStatus?.label ?? 'Belum dimulai'} → '
                      '${change.newStatus.label}',
                    ),
                    subtitle: Text(_formatDate(change.changedAt)),
                    trailing: Text('Ayat ${change.globalAyahNumber}'),
                    onTap: () => _openAyah(change.globalAyahNumber),
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}

class _SessionTile extends StatefulWidget {
  const _SessionTile({
    required this.session,
    required this.dateLabel,
    required this.onLoadAyahs,
    required this.onOpenAyah,
  });

  final MemorizationSession session;
  final String dateLabel;
  final Future<List<MemorizationSessionAyah>> Function() onLoadAyahs;
  final ValueChanged<int> onOpenAyah;

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  late Future<List<MemorizationSessionAyah>> _ayahs;

  @override
  void initState() {
    super.initState();
    _ayahs = widget.onLoadAyahs();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.event_note_rounded),
      title: Text(widget.session.mode.label),
      subtitle: Text(
        '${widget.dateLabel} · ${widget.session.newAyahCount} ayat baru · '
        '${widget.session.repeatedAyahCount} pengulangan',
      ),
      children: [
        FutureBuilder<List<MemorizationSessionAyah>>(
          future: _ayahs,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Gagal memuat detail sesi: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.data!.isEmpty) {
              return const ListTile(title: Text('Tidak ada ayat tercatat.'));
            }
            return Column(
              children: [
                for (final ayah in snapshot.data!)
                  ListTile(
                    dense: true,
                    title: Text('Ayat #${ayah.globalAyahNumber}'),
                    subtitle: Text(
                      '${ayah.attempts} kali · '
                      '${ayah.newlyLearned ? 'ayat baru' : 'diulang'}',
                    ),
                    onTap: () => widget.onOpenAyah(ayah.globalAyahNumber),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _HistoryData {
  const _HistoryData(this.sessions, this.changes);

  final List<MemorizationSession> sessions;
  final List<MemorizationStatusChange> changes;
}

class _HistoryReaderPreferences extends AppPreferences {
  const _HistoryReaderPreferences();

  @override
  Future<String?> get selectedVoiceId async =>
      const AppPreferences().selectedVoiceId;
}
