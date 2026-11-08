import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../reading/data/reading_repository.dart';
import '../../reading/presentation/reading_screen.dart';
import '../data/memorization_repository.dart';
import '../domain/memorization_models.dart';

class MemorizationPracticeScreen extends StatefulWidget {
  const MemorizationPracticeScreen({
    super.key,
    required this.program,
    required this.repository,
    required this.readingRepository,
    required this.initialMode,
  });

  final MemorizationProgram program;
  final MemorizationRepository repository;
  final ReadingRepository readingRepository;
  final MemorizationSessionMode initialMode;

  @override
  State<MemorizationPracticeScreen> createState() =>
      _MemorizationPracticeScreenState();
}

class _MemorizationPracticeScreenState
    extends State<MemorizationPracticeScreen> {
  late Future<void> _initialization;
  List<AyahEntry> _ayahs = const [];
  Map<int, MemorizationAyahProgress> _progress = const {};
  DailyMemorizationProgress? _dailyProgress;
  MemorizationSession? _session;
  int _currentIndex = 0;
  bool _revealed = false;
  bool _saving = false;
  String? _error;

  bool get _hideAyah =>
      (widget.initialMode == MemorizationSessionMode.hideReveal ||
          widget.initialMode == MemorizationSessionMode.recall) &&
      !_revealed;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      final ayahs = await widget.repository.getProgramAyahs(widget.program);
      if (ayahs.isEmpty) throw StateError('Ayat dalam program tidak tersedia.');
      final progress = await widget.repository.getProgress(widget.program.id);
      final nextIndex = ayahs.indexWhere(
        (ayah) =>
            progress[ayah.globalNumber]?.status != MemorizationStatus.mastered,
      );
      final session = await widget.repository.startSession(
        programId: widget.program.id,
        mode: widget.initialMode,
      );
      if (!mounted) return;
      setState(() {
        _ayahs = ayahs;
        _progress = progress;
        _currentIndex = nextIndex < 0 ? 0 : nextIndex;
        _session = session;
      });
      await _recordCurrentAyah();
    } catch (error) {
      if (mounted) setState(() => _error = 'Gagal memulai latihan: $error');
    }
  }

  AyahEntry get _currentAyah => _ayahs[_currentIndex];

  Future<void> _recordCurrentAyah() async {
    final session = _session;
    if (session == null || _ayahs.isEmpty) return;
    try {
      await widget.repository.recordPractice(
        sessionId: session.id,
        globalAyahNumber: _currentAyah.globalNumber,
      );
      await _refreshProgress();
    } catch (error) {
      if (mounted) setState(() => _error = 'Gagal menyimpan latihan: $error');
    }
  }

  Future<void> _refreshProgress() async {
    final result = await Future.wait([
      widget.repository.getProgress(widget.program.id),
      widget.repository.getDailyProgress(widget.program),
      if (_session != null) widget.repository.getSessions(widget.program.id),
    ]);
    if (!mounted) return;
    setState(() {
      _progress = result[0] as Map<int, MemorizationAyahProgress>;
      _dailyProgress = result[1] as DailyMemorizationProgress;
      if (_session != null) {
        final sessions = result[2] as List<MemorizationSession>;
        _session = sessions.firstWhere(
          (item) => item.id == _session!.id,
          orElse: () => _session!,
        );
      }
    });
  }

  Future<void> _move(int delta) async {
    final nextIndex = _currentIndex + delta;
    if (nextIndex < 0 || nextIndex >= _ayahs.length || _saving) return;
    setState(() {
      _currentIndex = nextIndex;
      _revealed = false;
      _error = null;
    });
    await _recordCurrentAyah();
  }

  Future<void> _changeStatus(MemorizationStatus status) async {
    if (status == MemorizationStatus.mastered) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi hafalan'),
          content: const Text(
            'Tandai ayat ini sebagai dikuasai? Status ini ditetapkan '
            'berdasarkan konfirmasi Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Belum'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tandai dikuasai'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateStatus(
        programId: widget.program.id,
        globalAyahNumber: _currentAyah.globalNumber,
        status: status,
        sessionId: _session?.id,
      );
      await _refreshProgress();
    } catch (error) {
      if (mounted) setState(() => _error = 'Gagal memperbarui status: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openReader() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.readingRepository,
          preferences: const _PracticeReaderPreferences(),
          surahNumber: _currentAyah.surahNumber,
          startingAyah: _currentAyah.ayahNumber,
          saveReadingProgress: false,
          preserveExistingAudioQueue: true,
        ),
      ),
    );
    if (mounted) await _refreshProgress();
  }

  Future<void> _finish() async {
    final session = _session;
    if (session != null) {
      try {
        await widget.repository.finishSession(session.id);
      } catch (error) {
        if (mounted) {
          setState(() => _error = 'Gagal menyimpan akhir sesi: $error');
        }
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initialMode.label),
      actions: [TextButton(onPressed: _finish, child: const Text('Selesai'))],
    ),
    body: FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (_error != null && _ayahs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!),
            ),
          );
        }
        if (_ayahs.isEmpty ||
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final ayah = _currentAyah;
        final status =
            _progress[ayah.globalNumber]?.status ??
            MemorizationStatus.notStarted;
        final daily = _dailyProgress;
        return Column(
          children: [
            if (daily != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target hari ini: ${daily.completedNewAyahs}/'
                      '${widget.program.dailyTarget} ayat baru',
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: daily.fraction,
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${ayah.surahNameIndonesian ?? 'Surah ${ayah.surahNumber}'} '
                    '${ayah.surahNumber}:${ayah.ayahNumber}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ayat ${_currentIndex + 1} dari ${_ayahs.length} · '
                    '${status.label}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: _hideAyah
                          ? Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.visibility_off_outlined,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Coba ingat ayatnya terlebih dahulu.',
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.tonal(
                                    onPressed: () =>
                                        setState(() => _revealed = true),
                                    child: const Text('Tampilkan ayat'),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Text(
                                  ayah.uthmaniText,
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontFamily: 'AmiriQuran',
                                    fontSize: 30,
                                    height: 1.8,
                                  ),
                                ),
                                if (ayah.transliteration case final text?
                                    when text.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(text, textAlign: TextAlign.center),
                                ],
                                if (ayah.indonesianTranslation
                                    case final translation?
                                    when translation.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    translation,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                                if (widget.initialMode !=
                                    MemorizationSessionMode.learn)
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _revealed = false),
                                    icon: const Icon(
                                      Icons.visibility_off_outlined,
                                    ),
                                    label: const Text('Sembunyikan lagi'),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      for (final nextStatus in [
                        MemorizationStatus.notStarted,
                        MemorizationStatus.learning,
                        MemorizationStatus.inProgress,
                        MemorizationStatus.needsReview,
                        MemorizationStatus.mastered,
                      ])
                        ChoiceChip(
                          label: Text(nextStatus.label),
                          selected: status == nextStatus,
                          onSelected: _saving
                              ? null
                              : (_) => _changeStatus(nextStatus),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openReader,
                    icon: const Icon(Icons.headphones_rounded),
                    label: const Text('Buka di Quran Reader / audio'),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentIndex > 0 ? () => _move(-1) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Sebelumnya'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _currentIndex + 1 < _ayahs.length
                            ? () => _move(1)
                            : _finish,
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: Text(
                          _currentIndex + 1 < _ayahs.length
                              ? 'Berikutnya'
                              : 'Selesai',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _PracticeReaderPreferences extends AppPreferences {
  const _PracticeReaderPreferences();

  @override
  Future<String?> get selectedVoiceId async =>
      const AppPreferences().selectedVoiceId;
}
