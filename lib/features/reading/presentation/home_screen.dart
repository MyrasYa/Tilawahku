import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../download/presentation/download_screen.dart';
import '../../memorization/data/memorization_repository.dart';
import '../../memorization/presentation/memorization_home_screen.dart';
import '../../player/data/quran_audio_handler.dart';
import '../../settings/presentation/settings_screen.dart';
import '../data/reading_repository.dart';
import 'bookmarks_screen.dart';
import 'reading_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.preferences,
    required this.onSetDarkMode,
    this.repository,
    this.memorizationRepository,
  });

  final AppPreferences preferences;
  final ValueChanged<bool> onSetDarkMode;
  final ReadingRepository? repository;
  final MemorizationRepository? memorizationRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ReadingRepository _repository;
  late final MemorizationRepository _memorizationRepository;
  late Future<List<Surah>> _surahs;
  String? _voiceId;
  String? _loadError;
  AyahEntry? _lastProgress;
  bool _loadingProgress = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ReadingRepository();
    _memorizationRepository =
        widget.memorizationRepository ??
        MemorizationRepository(readingRepository: _repository);
    _surahs = _repository.getSurahs();
    _loadVoice();
  }

  Future<void> _loadVoice() async {
    try {
      final voiceId = await widget.preferences.selectedVoiceId;
      if (!mounted) return;
      setState(() {
        _voiceId = voiceId;
        _loadError = null;
      });
      await _loadProgress(voiceId);
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  Future<void> _loadProgress(String? voiceId) async {
    if (mounted) {
      setState(() {
        _loadingProgress = voiceId != null;
        if (voiceId == null) _lastProgress = null;
      });
    }
    if (voiceId == null) return;
    try {
      final progress = await _repository.getProgress(voiceId);
      if (!mounted) return;
      setState(() {
        _lastProgress = progress;
        _loadingProgress = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProgress = false;
        _loadError = 'Gagal memuat progres: $error';
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          preferences: widget.preferences,
          onSetDarkMode: widget.onSetDarkMode,
        ),
      ),
    );
    if (!mounted) return;
    await _loadVoice();
    setState(() {
      _surahs = _repository.getSurahs();
    });
  }

  void _reloadSurahs() {
    setState(() {
      _surahs = _repository.getSurahs();
    });
  }

  Future<void> _continueLast() async {
    final voiceId = _voiceId;
    if (voiceId == null) {
      await _openReading(surahNumber: 1);
      return;
    }
    try {
      await _loadProgress(voiceId);
      if (!mounted) return;
      final position = _lastProgress;
      if (position == null) {
        await _openReading(surahNumber: 1);
        return;
      }
      await _openReading(
        surahNumber: position.surahNumber,
        startingAyah: position.ayahNumber,
      );
    } catch (error) {
      if (mounted) _showMessage('Gagal memuat progres: $error');
    }
  }

  Future<void> _toggleCurrentPlayback() async {
    final handler = QuranAudioHandler.instance;
    if (handler == null) return;
    try {
      if (handler.playbackState.value.playing) {
        await handler.pause();
      } else {
        await handler.play();
      }
    } catch (error) {
      if (mounted) _showMessage('Gagal mengendalikan audio: $error');
    }
  }

  Future<void> _openPlayingAyah() async {
    final handler = QuranAudioHandler.instance;
    final item = handler?.mediaItem.value;
    final surahNumber = item?.extras?['surahNumber'];
    final ayahNumber = item?.extras?['ayahNumber'];
    if (surahNumber is! int || ayahNumber is! int) {
      _showMessage('Informasi ayat yang sedang diputar tidak tersedia.');
      return;
    }
    await _openReading(surahNumber: surahNumber, startingAyah: ayahNumber);
  }

  Future<void> _openReading({
    int? surahNumber,
    int? startingAyah,
    int? juzNumber,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReadingScreen(
          repository: _repository,
          preferences: widget.preferences,
          surahNumber: surahNumber,
          startingAyah: startingAyah,
          juzNumber: juzNumber,
        ),
      ),
    );
    if (mounted && _voiceId != null) await _loadProgress(_voiceId);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/branding/tilawahku_icon.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'Tilawahku',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cari ayat',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SearchScreen(
                  repository: _repository,
                  preferences: widget.preferences,
                ),
              ),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Bookmark ayat',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => BookmarksScreen(
                  repository: _repository,
                  preferences: widget.preferences,
                ),
              ),
            ),
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          IconButton(
            tooltip: 'Hafalan Al-Qur’an',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => MemorizationHomeScreen(
                  repository: _memorizationRepository,
                  readingRepository: _repository,
                ),
              ),
            ),
            icon: const Icon(Icons.psychology_alt_outlined),
          ),
          IconButton(
            tooltip: 'Unduhan',
            onPressed: kIsWeb
                ? () => _showMessage(
                    'Audio belum tersedia secara lokal di Web preview. '
                    'Unduhan audio tidak diaktifkan di browser.',
                  )
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DownloadScreen(preferences: widget.preferences),
                    ),
                  ),
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Juz'),
            Tab(text: 'Surah'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (kIsWeb)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _WebPreviewNotice(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _HomePlaybackSection(
              handler: QuranAudioHandler.instance,
              voiceId: _voiceId,
              progress: _lastProgress,
              isLoading: _loadingProgress,
              error: _loadError,
              onContinue: _continueLast,
              onOpenReading: _openPlayingAyah,
              onTogglePlayback: _toggleCurrentPlayback,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _JuzList(onSelected: (juz) => _openReading(juzNumber: juz)),
                _SurahList(
                  surahs: _surahs,
                  onRetry: _reloadSurahs,
                  onSelected: (surah) => _openReading(surahNumber: surah.id),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomePlaybackSection extends StatelessWidget {
  const _HomePlaybackSection({
    required this.handler,
    required this.voiceId,
    required this.progress,
    required this.isLoading,
    required this.error,
    required this.onContinue,
    required this.onOpenReading,
    required this.onTogglePlayback,
  });

  final QuranAudioHandler? handler;
  final String? voiceId;
  final AyahEntry? progress;
  final bool isLoading;
  final String? error;
  final VoidCallback onContinue;
  final VoidCallback onOpenReading;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
    stream: handler?.mediaItem,
    initialData: handler?.mediaItem.value,
    builder: (context, snapshot) {
      final item = snapshot.data;
      if (handler == null ||
          voiceId == null ||
          item == null ||
          handler!.queue.value.isEmpty) {
        return _ContinueCard(
          onPressed: onContinue,
          voiceId: voiceId,
          progress: progress,
          isLoading: isLoading,
          error: error,
        );
      }
      return _NowPlayingCard(
        handler: handler!,
        item: item,
        onOpenReading: onOpenReading,
        onTogglePlayback: onTogglePlayback,
      );
    },
  );
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.handler,
    required this.item,
    required this.onOpenReading,
    required this.onTogglePlayback,
  });

  final QuranAudioHandler handler;
  final MediaItem item;
  final VoidCallback onOpenReading;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.blue,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpenReading,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.gold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.parchment,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.artist ?? 'Qari'} · '
                        '${item.album ?? 'Tilawahku'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.parchment.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<PlaybackState>(
                  stream: handler.playbackState,
                  initialData: handler.playbackState.value,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton.filled(
                      tooltip: playing ? 'Jeda audio' : 'Putar audio',
                      onPressed: onTogglePlayback,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    );
                  },
                ),
              ],
            ),
            StreamBuilder<Duration?>(
              stream: handler.durationStream,
              initialData: handler.duration,
              builder: (context, durationSnapshot) {
                final duration = durationSnapshot.data;
                if (duration == null || duration <= Duration.zero) {
                  return const SizedBox(height: 4);
                }
                return StreamBuilder<Duration>(
                  stream: handler.positionStream,
                  initialData: handler.position,
                  builder: (context, positionSnapshot) {
                    final progress =
                        (positionSnapshot.data!.inMilliseconds /
                                duration.inMilliseconds)
                            .clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: AppColors.navy,
                        color: AppColors.gold,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.onPressed,
    required this.voiceId,
    required this.progress,
    required this.isLoading,
    required this.error,
  });

  final VoidCallback onPressed;
  final String? voiceId;
  final AyahEntry? progress;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.navy,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.7)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.blue, AppColors.navy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
              child: Icon(
                progress == null
                    ? Icons.menu_book_rounded
                    : Icons.play_arrow_rounded,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress == null ? 'Mulai Membaca' : 'Lanjutkan Terakhir',
                    style: const TextStyle(
                      color: AppColors.parchment,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error ??
                        (isLoading
                            ? 'Memuat progres tilawah...'
                            : progress != null
                            ? '${progress!.surahNameIndonesian ?? 'Surah ${progress!.surahNumber}'}'
                                  ' · Ayat ${progress!.ayahNumber}'
                            : voiceId == null
                            ? 'Audio belum tersedia secara lokal · Anda tetap bisa membaca'
                            : 'Belum ada progres · mulai dari Al-Fatihah'),
                    style: const TextStyle(
                      color: AppColors.parchment,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold),
          ],
        ),
      ),
    ),
  );
}

class _WebPreviewNotice extends StatelessWidget {
  const _WebPreviewNotice();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Web preview: teks, bookmark, navigasi, dan preferensi tersedia. '
              'Audio tidak tersedia secara lokal; pemutaran dan unduhan '
              'dinonaktifkan di browser.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    itemCount: 30,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final juz = index + 1;
      return Card(
        child: ListTile(
          minTileHeight: 64,
          leading: CircleAvatar(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.navy,
            radius: 22,
            child: Text('$juz'),
          ),
          title: Text('Juz $juz'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelected(juz),
        ),
      );
    },
  );
}

class _SurahList extends StatelessWidget {
  const _SurahList({
    required this.surahs,
    required this.onRetry,
    required this.onSelected,
  });

  final Future<List<Surah>> surahs;
  final VoidCallback onRetry;
  final ValueChanged<Surah> onSelected;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Surah>>(
    future: surahs,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gagal memuat daftar surah: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
                TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = snapshot.data!;
      if (items.isEmpty) {
        return const _EmptyContent(
          message:
              'Daftar surah akan tersedia setelah database Qur’an dipasang.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final surah = items[index];
          return Card(
            child: ListTile(
              minTileHeight: 64,
              leading: CircleAvatar(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                radius: 22,
                child: Text('${surah.id}'),
              ),
              title: Text(surah.nameIndonesian),
              subtitle: Text('${surah.ayahCount} ayat'),
              trailing: Text(
                surah.nameArabic,
                textDirection: TextDirection.rtl,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => onSelected(surah),
            ),
          );
        },
      );
    },
  );
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 52, color: AppColors.gold),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
