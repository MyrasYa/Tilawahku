import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../app/app_theme.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../download/data/audio_download_manager.dart';
import '../../player/data/audio_repository.dart';
import '../../player/data/quran_audio_handler.dart';
import '../../voices/data/voice_catalog.dart';
import '../data/reading_repository.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.repository,
    required this.preferences,
    this.surahNumber,
    this.juzNumber,
    this.pageNumber,
    this.startingAyah,
  }) : assert(surahNumber != null || juzNumber != null || pageNumber != null);

  final ReadingRepository repository;
  final AppPreferences preferences;
  final int? surahNumber;
  final int? juzNumber;
  final int? pageNumber;
  final int? startingAyah;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late Future<List<AyahEntry>> _ayahs;
  int? _displayedSurahNumber;
  int? _displayedJuzNumber;
  int? _displayedPageNumber;
  int? _startingAyah;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final TextEditingController _pageController = TextEditingController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  List<AyahEntry> _loadedAyahs = const [];
  Set<int> _loadedGlobalNumbers = const {};
  bool _ayahsLoaded = false;
  int? _pendingScrollGlobalNumber;
  int? _lastScrollGlobalNumber;
  bool _showTranslation = true;
  double _arabicTextScale = 1;
  Voice? _voice;
  String? _progressVoiceId;
  Set<int> _bookmarkedNumbers = {};
  String? _error;
  int? _currentAyahNumber;
  int? _lastSavedProgressAyahNumber;
  int? _loadingAyahNumber;
  bool _isPlaying = false;
  bool _isPreparingAll = false;
  bool _isSelectingPlayAll = false;
  bool _allAyahsQueueLoaded = false;
  bool _followAudioQueue = false;
  _PlayAllSelection? _lastPlayAllSelection;
  int _preparingAyah = 0;
  int _preparingTotal = 0;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  Timer? _progressSaveDebounce;
  final AudioDownloadManager _downloadManager = AudioDownloadManager.instance;
  final AudioRepository _audioRepository = AudioRepository();

  @override
  void initState() {
    super.initState();
    _displayedSurahNumber = widget.surahNumber;
    _displayedJuzNumber = widget.juzNumber;
    _displayedPageNumber = widget.pageNumber;
    _startingAyah = widget.startingAyah;
    _ayahs = _loadAyahs();
    _loadPreferences();
    _itemPositionsListener.itemPositions.addListener(
      _scheduleVisibleProgressSave,
    );
    _mediaItemSubscription = QuranAudioHandler.instance?.mediaItem.listen((
      item,
    ) {
      _syncPlaybackIndicator(adoptQueue: true);
    });
    _playbackStateSubscription = QuranAudioHandler.instance?.playbackState
        .listen((state) {
          _syncPlaybackIndicator(adoptQueue: true);
        });
    _syncPlaybackIndicator();
  }

  void _syncPlaybackIndicator({bool adoptQueue = false}) {
    if (!mounted) return;
    final handler = QuranAudioHandler.instance;
    final activeMediaItem = handler?.mediaItem.value;
    final queue = handler?.queue.value ?? const <MediaItem>[];
    final voice = _voice;
    if (adoptQueue &&
        !_followAudioQueue &&
        voice != null &&
        activeMediaItem?.artist == voice.name &&
        _loadedGlobalNumbers.contains(
          int.tryParse(activeMediaItem?.id ?? ''),
        ) &&
        queue.isNotEmpty) {
      _followAudioQueue = true;
      _allAyahsQueueLoaded = queue.length > 1;
    }
    final currentAyahNumber = _followAudioQueue
        ? int.tryParse(activeMediaItem?.id ?? '')
        : null;
    final isPlaying =
        _followAudioQueue && (handler?.playbackState.value.playing ?? false);
    if (currentAyahNumber != null &&
        currentAyahNumber != _lastScrollGlobalNumber) {
      _lastScrollGlobalNumber = currentAyahNumber;
      _scrollToAyah(currentAyahNumber);
    }
    if (isPlaying &&
        currentAyahNumber != null &&
        currentAyahNumber != _lastSavedProgressAyahNumber) {
      _lastSavedProgressAyahNumber = currentAyahNumber;
      final voiceId = _voice?.id;
      if (voiceId != null) {
        unawaited(_saveProgress(voiceId, currentAyahNumber));
      }
    }
    if (currentAyahNumber == _currentAyahNumber && isPlaying == _isPlaying) {
      return;
    }
    setState(() {
      _currentAyahNumber = currentAyahNumber;
      _isPlaying = isPlaying;
    });
  }

  Future<void> _saveProgress(String voiceId, int globalAyahNumber) async {
    try {
      await widget.repository.saveProgress(
        voiceId: voiceId,
        globalAyahNumber: globalAyahNumber,
      );
    } catch (error) {
      _showAudioMessage('Gagal menyimpan progres tilawah: $error');
    }
  }

  Future<List<AyahEntry>> _loadAyahs() async {
    final List<AyahEntry> entries;
    if (_displayedPageNumber case final page?) {
      entries = await widget.repository.getAyahsForPage(page);
    } else if (_displayedJuzNumber case final juz?) {
      entries = await widget.repository.getAyahsForJuz(juz);
    } else {
      entries = await widget.repository.getAyahsForSurah(
        _displayedSurahNumber!,
      );
    }
    _loadedAyahs = entries;
    _loadedGlobalNumbers = entries.map((ayah) => ayah.globalNumber).toSet();
    _ayahsLoaded = true;
    unawaited(_loadBookmarks(entries));
    final pendingGlobalNumber = _pendingScrollGlobalNumber;
    if (pendingGlobalNumber != null) _scrollToAyah(pendingGlobalNumber);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPlaybackIndicator(adoptQueue: true);
      _saveInitialProgress();
      _scheduleVisibleProgressSave();
    });
    return entries;
  }

  void _saveInitialProgress() {
    final voiceId = _progressVoiceId;
    if (voiceId == null || _loadedAyahs.isEmpty) return;
    final initialIndex = _startingAyah == null
        ? 0
        : _loadedAyahs.indexWhere((ayah) => ayah.ayahNumber == _startingAyah);
    if (initialIndex < 0 || initialIndex >= _loadedAyahs.length) return;

    final ayah = _loadedAyahs[initialIndex];
    if (ayah.globalNumber == _lastSavedProgressAyahNumber) return;
    _lastSavedProgressAyahNumber = ayah.globalNumber;
    unawaited(_saveProgress(voiceId, ayah.globalNumber));
  }

  Future<void> _loadBookmarks(List<AyahEntry> ayahs) async {
    try {
      final bookmarkedNumbers = await widget.repository.getBookmarkedNumbers(
        ayahs.map((ayah) => ayah.globalNumber).toList(growable: false),
      );
      if (mounted) setState(() => _bookmarkedNumbers = bookmarkedNumbers);
    } catch (error) {
      _showAudioMessage('Gagal memuat bookmark ayat: $error');
    }
  }

  Future<void> _toggleBookmark(AyahEntry ayah) async {
    final bookmarked = !_bookmarkedNumbers.contains(ayah.globalNumber);
    try {
      await widget.repository.setBookmarked(ayah.globalNumber, bookmarked);
      if (!mounted) return;
      setState(() {
        if (bookmarked) {
          _bookmarkedNumbers = {..._bookmarkedNumbers, ayah.globalNumber};
        } else {
          _bookmarkedNumbers = {..._bookmarkedNumbers}
            ..remove(ayah.globalNumber);
        }
      });
    } catch (error) {
      _showAudioMessage('Gagal menyimpan bookmark: $error');
    }
  }

  void _scheduleVisibleProgressSave() {
    _progressSaveDebounce?.cancel();
    final voiceId = _progressVoiceId;
    if (voiceId == null || _loadedAyahs.isEmpty) return;

    final visiblePositions =
        _itemPositionsListener.itemPositions.value
            .where(
              (position) =>
                  position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1,
            )
            .toList()
          ..sort((first, second) {
            final edgeOrder = first.itemLeadingEdge.compareTo(
              second.itemLeadingEdge,
            );
            return edgeOrder != 0
                ? edgeOrder
                : first.index.compareTo(second.index);
          });
    final initialIndex = _startingAyah == null
        ? 0
        : _loadedAyahs.indexWhere((ayah) => ayah.ayahNumber == _startingAyah);
    final index = visiblePositions.isEmpty
        ? initialIndex < 0
              ? 0
              : initialIndex
        : visiblePositions.first.index;
    if (index >= _loadedAyahs.length) {
      return;
    }

    final ayah = _loadedAyahs[index];
    if (ayah.globalNumber == _lastSavedProgressAyahNumber) return;
    _progressSaveDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _progressVoiceId != voiceId) return;
      _lastSavedProgressAyahNumber = ayah.globalNumber;
      unawaited(_saveProgress(voiceId, ayah.globalNumber));
    });
  }

  Future<void> _choosePage() async {
    try {
      final pageCount = await widget.repository.getPageCount();
      if (!mounted) return;
      if (pageCount == 0) {
        throw StateError('Data halaman Qur’an belum tersedia.');
      }

      _pageController.text = '${_displayedPageNumber ?? 1}';
      final pageNumber = await showDialog<int>(
        context: context,
        builder: (context) {
          String? validationError;
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Buka halaman'),
              content: TextField(
                controller: _pageController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nomor halaman',
                  helperText: 'Pilih halaman 1–$pageCount.',
                  errorText: validationError,
                ),
                onSubmitted: (_) {
                  final value = int.tryParse(_pageController.text.trim());
                  if (value == null || value < 1 || value > pageCount) {
                    setDialogState(
                      () => validationError =
                          'Masukkan nomor halaman dari 1 sampai $pageCount.',
                    );
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = int.tryParse(_pageController.text.trim());
                    if (value == null || value < 1 || value > pageCount) {
                      setDialogState(
                        () => validationError =
                            'Masukkan nomor halaman dari 1 sampai $pageCount.',
                      );
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Buka'),
                ),
              ],
            ),
          );
        },
      );
      if (!mounted || pageNumber == null) return;

      setState(() {
        _displayedPageNumber = pageNumber;
        _displayedJuzNumber = null;
        _displayedSurahNumber = null;
        _startingAyah = null;
        _ayahs = _loadAyahs();
      });
    } catch (error) {
      if (mounted) _showAudioMessage('Gagal membuka halaman: $error');
    }
  }

  void _scrollToAyah(int globalAyahNumber) {
    final index = _loadedAyahs.indexWhere(
      (ayah) => ayah.globalNumber == globalAyahNumber,
    );
    if (index < 0) {
      _pendingScrollGlobalNumber = _ayahsLoaded ? null : globalAyahNumber;
      return;
    }

    _pendingScrollGlobalNumber = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached) return;
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final visible = await widget.preferences.translationVisible;
      final scale = await widget.preferences.arabicTextScale;
      final voiceId = await widget.preferences.selectedVoiceId;
      if (!mounted) return;
      setState(() {
        _showTranslation = visible;
        _arabicTextScale = scale;
        _progressVoiceId = voiceId;
      });
      _saveInitialProgress();
      _scheduleVisibleProgressSave();

      final voices = await const VoiceCatalog().load();
      final voice = voices.where((item) => item.id == voiceId).firstOrNull;
      if (!mounted) return;
      setState(() => _voice = voice);
      _syncPlaybackIndicator(adoptQueue: true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _toggleTranslation(bool value) async {
    setState(() => _showTranslation = value);
    try {
      await widget.preferences.setTranslationVisible(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Gagal menyimpan preferensi terjemahan: $error');
    }
  }

  Future<void> _playAyah(AyahEntry ayah) async {
    final handler = QuranAudioHandler.instance;
    final voice = _voice;
    if (handler == null ||
        voice == null ||
        voice.status != VoiceStatus.active) {
      _showAudioMessage('Pilih qari aktif terlebih dahulu di Pengaturan.');
      return;
    }

    final currentMediaId = _followAudioQueue
        ? handler.mediaItem.value?.id
        : null;
    if (currentMediaId == '${ayah.globalNumber}') {
      try {
        if (handler.playbackState.value.playing) {
          await handler.pause();
        } else {
          await handler.setRepeatMode(AudioServiceRepeatMode.one);
          _startPlayback(handler);
        }
      } catch (error) {
        _showAudioMessage('Gagal mengubah pemutaran audio: $error');
      }
      return;
    }

    setState(() {
      _loadingAyahNumber = ayah.globalNumber;
      _allAyahsQueueLoaded = false;
      _followAudioQueue = false;
    });
    try {
      final tracks = await _audioRepository.getSurahTracks(
        surahNumber: ayah.surahNumber,
        voiceId: voice.id,
      );
      final matchingTracks = tracks
          .where((track) => track.globalNumber == ayah.globalNumber)
          .toList(growable: false);
      if (matchingTracks.isEmpty) {
        throw StateError('Manifest audio untuk ayat ini tidak tersedia.');
      }
      final track = matchingTracks.single;
      if (!await _downloadManager.isAyahDownloaded(track)) {
        await _downloadManager.downloadAyah(voice: voice, track: track);
      }

      await handler.setRepeatMode(AudioServiceRepeatMode.one);
      await handler.loadTracks(
        [track],
        voiceName: voice.name,
        voiceId: voice.id,
      );
      _followAudioQueue = true;
      _syncPlaybackIndicator();
      _startPlayback(handler);
    } catch (error) {
      _showAudioMessage('Tidak dapat memutar ayat: $error');
    } finally {
      if (mounted) setState(() => _loadingAyahNumber = null);
    }
  }

  Future<void> _togglePlayAllAyahs({
    bool chooseSection = false,
    _PlayAllSelection? selectionToPlay,
  }) async {
    final handler = QuranAudioHandler.instance;
    if (!chooseSection && _allAyahsQueueLoaded && handler != null) {
      try {
        if (handler.playbackState.value.playing) {
          await handler.pause();
        } else {
          _startPlayback(
            handler,
            errorMessage: 'Tidak dapat melanjutkan semua ayat.',
          );
        }
      } catch (error) {
        _showAudioMessage('Gagal mengubah pemutaran semua ayat: $error');
      }
      return;
    }

    final voice = _voice;
    if (voice == null ||
        voice.status != VoiceStatus.active ||
        handler == null) {
      _showAudioMessage('Pilih qari aktif terlebih dahulu di Pengaturan.');
      return;
    }
    if (_isPreparingAll || _isSelectingPlayAll) return;

    var selection = selectionToPlay;
    if (selection == null) {
      setState(() => _isSelectingPlayAll = true);
      try {
        final surahs = await widget.repository.getSurahs();
        if (!mounted) return;
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetColor = isDark ? AppColors.blue : AppColors.parchment;
        selection = await showModalBottomSheet<_PlayAllSelection>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: sheetColor,
          barrierColor: Colors.black.withValues(alpha: isDark ? 0.72 : 0.48),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            side: BorderSide(
              color: isDark
                  ? colorScheme.outlineVariant.withValues(alpha: 0.65)
                  : Colors.transparent,
            ),
          ),
          builder: (sheetContext) => Theme(
            data: Theme.of(sheetContext).copyWith(
              canvasColor: sheetColor,
              bottomSheetTheme: BottomSheetThemeData(
                backgroundColor: sheetColor,
                modalBackgroundColor: sheetColor,
                surfaceTintColor: Colors.transparent,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
              ),
            ),
            child: _PlayAllScopeSheet(
              surahs: surahs,
              initialScope: _displayedJuzNumber == null
                  ? _PlayAllScope.surah
                  : _PlayAllScope.juz,
              initialSurahNumber: _displayedSurahNumber,
              initialJuzNumber: _displayedJuzNumber,
            ),
          ),
        );
      } catch (error) {
        _showAudioMessage('Gagal memuat pilihan surah dan juz: $error');
        return;
      } finally {
        if (mounted) setState(() => _isSelectingPlayAll = false);
      }
    }
    final chosenSelection = selection;
    if (chosenSelection == null || !mounted) return;
    _lastPlayAllSelection = chosenSelection;

    final isCurrentSection = chosenSelection.scope == _PlayAllScope.juz
        ? chosenSelection.number == _displayedJuzNumber
        : chosenSelection.number == _displayedSurahNumber;
    final startingAyah = isCurrentSection ? _startingAyah : null;
    setState(() {
      _displayedJuzNumber = chosenSelection.scope == _PlayAllScope.juz
          ? chosenSelection.number
          : null;
      _displayedSurahNumber = chosenSelection.scope == _PlayAllScope.surah
          ? chosenSelection.number
          : null;
      _startingAyah = startingAyah;
      _ayahs = _loadAyahs();
      _isPreparingAll = true;
      _preparingAyah = 0;
      _preparingTotal = 0;
      _error = null;
      _allAyahsQueueLoaded = false;
      _followAudioQueue = false;
    });
    try {
      final tracks = chosenSelection.scope == _PlayAllScope.juz
          ? await _audioRepository.getJuzTracks(
              juzNumber: chosenSelection.number,
              voiceId: voice.id,
            )
          : await _audioRepository.getSurahTracks(
              surahNumber: chosenSelection.number,
              voiceId: voice.id,
            );
      if (tracks.isEmpty) {
        throw StateError('Manifest audio untuk bagian ini belum tersedia.');
      }
      if (mounted) setState(() => _preparingTotal = tracks.length);
      for (var index = 0; index < tracks.length; index++) {
        final track = tracks[index];
        if (mounted) {
          setState(() {
            _preparingAyah = index + 1;
            _loadingAyahNumber = track.globalNumber;
          });
        }
        if (!await _downloadManager.isAyahDownloaded(track)) {
          await _downloadManager.downloadAyah(voice: voice, track: track);
        }
        if (mounted) setState(() => _loadingAyahNumber = null);
      }
      if (mounted) setState(() => _preparingAyah = tracks.length);
      final initialTrack = startingAyah == null
          ? 0
          : tracks.indexWhere((track) => track.ayahNumber >= startingAyah);
      await handler.setRepeatMode(AudioServiceRepeatMode.none);
      await handler.loadTracks(
        tracks,
        voiceName: voice.name,
        voiceId: voice.id,
        initialTrack: initialTrack < 0 ? 0 : initialTrack,
      );
      _followAudioQueue = true;
      if (mounted) {
        setState(() => _allAyahsQueueLoaded = true);
        _syncPlaybackIndicator();
      }
      _startPlayback(handler, errorMessage: 'Tidak dapat memutar semua ayat.');
    } catch (error) {
      _showPlayAllFailure(error);
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingAll = false;
          _loadingAyahNumber = null;
          _preparingAyah = 0;
          _preparingTotal = 0;
        });
      }
    }
  }

  Future<void> _retryPlayAllAyahs() async {
    final selection = _lastPlayAllSelection;
    await _togglePlayAllAyahs(chooseSection: true, selectionToPlay: selection);
  }

  void _startPlayback(
    QuranAudioHandler handler, {
    String errorMessage = 'Tidak dapat memutar ayat.',
  }) {
    unawaited(
      handler.play().catchError((Object error) {
        _showAudioMessage('$errorMessage $error');
      }),
    );
  }

  void _showAudioMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPlayAllFailure(Object error) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Coba lagi',
          textColor: colors.inversePrimary,
          onPressed: _retryPlayAllAyahs,
        ),
        content: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Unduhan audio terhenti: $error',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahCard(AyahEntry ayah) => _AyahCard(
    ayah: ayah,
    showTranslation: _showTranslation,
    textScale: _arabicTextScale,
    isBookmarked: _bookmarkedNumbers.contains(ayah.globalNumber),
    isPlaying: _currentAyahNumber == ayah.globalNumber && _isPlaying,
    isLoading: _loadingAyahNumber == ayah.globalNumber,
    playbackLocked: _isPreparingAll,
    onPlay: () => _playAyah(ayah),
    onToggleBookmark: () => _toggleBookmark(ayah),
  );

  @override
  void dispose() {
    unawaited(_mediaItemSubscription?.cancel());
    unawaited(_playbackStateSubscription?.cancel());
    _itemPositionsListener.itemPositions.removeListener(
      _scheduleVisibleProgressSave,
    );
    _progressSaveDebounce?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _displayedPageNumber != null
        ? 'Halaman $_displayedPageNumber'
        : _displayedJuzNumber == null
        ? 'Surah $_displayedSurahNumber'
        : 'Juz $_displayedJuzNumber';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Buka halaman',
            onPressed: _choosePage,
            icon: const Icon(Icons.find_in_page_outlined),
          ),
          IconButton.filled(
            tooltip:
                '${_isPreparingAll || _isSelectingPlayAll
                    ? 'Menyiapkan bacaan'
                    : _allAyahsQueueLoaded
                    ? _isPlaying
                          ? 'Jeda semua ayat'
                          : 'Lanjutkan semua ayat'
                    : 'Putar semua ayat'}. '
                'Tekan lama untuk memilih surah atau juz.',
            onPressed: _isPreparingAll || _isSelectingPlayAll
                ? null
                : _togglePlayAllAyahs,
            onLongPress: _isPreparingAll || _isSelectingPlayAll
                ? null
                : () => _togglePlayAllAyahs(chooseSection: true),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.gold
                  : AppColors.navy,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.navy
                  : AppColors.parchment,
            ),
            icon: _isPreparingAll || _isSelectingPlayAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _allAyahsQueueLoaded
                ? Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  )
                : const Icon(Icons.playlist_play_rounded),
          ),
          IconButton(
            tooltip: _showTranslation
                ? 'Sembunyikan terjemahan'
                : 'Tampilkan terjemahan',
            onPressed: () => _toggleTranslation(!_showTranslation),
            icon: Icon(
              _showTranslation
                  ? Icons.translate_rounded
                  : Icons.g_translate_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPreparingAll)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.library_music_rounded,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Menyiapkan bacaan',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _preparingTotal == 0
                                ? 'Memuat'
                                : '${((_preparingAyah / _preparingTotal) * 100).round()}%',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _preparingTotal == 0
                            ? null
                            : _preparingAyah / _preparingTotal,
                      ),
                      if (_preparingTotal > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Memeriksa dan mengunduh audio ayat '
                          '$_preparingAyah dari $_preparingTotal. '
                          'Pemutaran dimulai setelah siap.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<AyahEntry>>(
              future: _ayahs,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ReaderMessage(
                    message: 'Gagal memuat ayat: ${snapshot.error}',
                    action: TextButton(
                      onPressed: () {
                        setState(() {
                          _ayahs = _loadAyahs();
                        });
                      },
                      child: const Text('Coba lagi'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ayahs = snapshot.data!;
                if (ayahs.isEmpty) {
                  return _ReaderMessage(
                    message:
                        'Belum ada teks Qur’an lokal. Data belum diimpor sampai '
                        'edisi, riwayat, dan atribusinya diverifikasi.',
                    action: const SizedBox.shrink(),
                  );
                }

                final initialIndex = _startingAyah == null
                    ? 0
                    : ayahs.indexWhere(
                        (ayah) => ayah.ayahNumber == _startingAyah,
                      );
                return ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  initialScrollIndex: initialIndex < 0 ? 0 : initialIndex,
                  initialAlignment: initialIndex < 0 ? 0 : 0.04,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: ayahs.length,
                  itemBuilder: (context, index) => _buildAyahCard(ayahs[index]),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _error == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  const _AyahCard({
    required this.ayah,
    required this.showTranslation,
    required this.textScale,
    required this.isBookmarked,
    required this.isPlaying,
    required this.isLoading,
    required this.playbackLocked,
    required this.onPlay,
    required this.onToggleBookmark,
  });

  final AyahEntry ayah;
  final bool showTranslation;
  final double textScale;
  final bool isBookmarked;
  final bool isPlaying;
  final bool isLoading;
  final bool playbackLocked;
  final VoidCallback onPlay;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${ayah.surahNumber}:${ayah.ayahNumber}',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: isPlaying ? 'Jeda ayat' : 'Putar ayat',
                onPressed: isLoading || playbackLocked ? null : onPlay,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Icon(
                    key: ValueKey(isPlaying ? 'pause' : 'play'),
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: AppColors.gold,
                  ),
                ),
              ),
              IconButton(
                tooltip: isBookmarked ? 'Hapus bookmark' : 'Simpan bookmark',
                onPressed: onToggleBookmark,
                icon: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ayah.uthmaniText,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'AmiriQuran',
              height: 1.9,
              fontSize:
                  (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) *
                  textScale,
            ),
          ),
          if (ayah.transliteration != null) ...[
            const SizedBox(height: 8),
            Text(
              ayah.transliteration!,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                height: 1.5,
              ),
            ),
          ],
          if (showTranslation && ayah.indonesianTranslation != null) ...[
            const SizedBox(height: 12),
            Text(
              ayah.indonesianTranslation!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    ),
  );
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({required this.message, required this.action});

  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.gold),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          action,
        ],
      ),
    ),
  );
}

enum _PlayAllScope { surah, juz }

class _PlayAllSelection {
  const _PlayAllSelection({required this.scope, required this.number});

  final _PlayAllScope scope;
  final int number;
}

class _PlayAllScopeSheet extends StatefulWidget {
  const _PlayAllScopeSheet({
    required this.surahs,
    required this.initialScope,
    required this.initialSurahNumber,
    required this.initialJuzNumber,
  });

  final List<Surah> surahs;
  final _PlayAllScope initialScope;
  final int? initialSurahNumber;
  final int? initialJuzNumber;

  @override
  State<_PlayAllScopeSheet> createState() => _PlayAllScopeSheetState();
}

class _PlayAllScopeSheetState extends State<_PlayAllScopeSheet> {
  late _PlayAllScope _scope;
  late int _selectedSurahNumber;
  late int _selectedJuzNumber;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope;
    _selectedSurahNumber =
        widget.surahs.any((surah) => surah.id == widget.initialSurahNumber)
        ? widget.initialSurahNumber!
        : widget.surahs.first.id;
    _selectedJuzNumber = widget.initialJuzNumber ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? AppColors.navy : AppColors.parchment;
    final selectedSurah = widget.surahs.firstWhere(
      (surah) => surah.id == _selectedSurahNumber,
    );
    final selection = _scope == _PlayAllScope.juz
        ? _PlayAllSelection(scope: _scope, number: _selectedJuzNumber)
        : _PlayAllSelection(scope: _scope, number: _selectedSurahNumber);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Putar semua ayat',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih surah atau juz. Audio yang belum tersimpan akan diunduh '
              'sebelum pemutaran dimulai.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SegmentedButton<_PlayAllScope>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return isDark ? AppColors.gold : AppColors.navy;
                  }
                  return fieldColor;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return isDark ? AppColors.navy : AppColors.parchment;
                  }
                  return colorScheme.onSurface;
                }),
                side: WidgetStatePropertyAll(
                  BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _PlayAllScope.juz,
                  label: Text('Juz'),
                  icon: Icon(Icons.auto_stories_rounded),
                ),
                ButtonSegment(
                  value: _PlayAllScope.surah,
                  label: Text('Surah'),
                  icon: Icon(Icons.menu_book_rounded),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (selection) {
                setState(() => _scope = selection.first);
              },
            ),
            const SizedBox(height: 16),
            if (_scope == _PlayAllScope.surah)
              DropdownButtonFormField<int>(
                key: const ValueKey(_PlayAllScope.surah),
                initialValue: _selectedSurahNumber,
                isExpanded: true,
                dropdownColor: fieldColor,
                iconEnabledColor: colorScheme.primary,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Pilih surah',
                  border: OutlineInputBorder(),
                ),
                items: widget.surahs
                    .map(
                      (surah) => DropdownMenuItem(
                        value: surah.id,
                        child: Text(
                          '${surah.id}. ${surah.nameIndonesian} '
                          '· ${surah.ayahCount} ayat',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (surahNumber) {
                  if (surahNumber != null) {
                    setState(() => _selectedSurahNumber = surahNumber);
                  }
                },
              )
            else
              DropdownButtonFormField<int>(
                key: const ValueKey(_PlayAllScope.juz),
                initialValue: _selectedJuzNumber,
                dropdownColor: fieldColor,
                iconEnabledColor: colorScheme.primary,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Pilih juz',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  30,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('Juz ${index + 1}'),
                  ),
                ),
                onChanged: (juzNumber) {
                  if (juzNumber != null) {
                    setState(() => _selectedJuzNumber = juzNumber);
                  }
                },
              ),
            if (_scope == _PlayAllScope.surah) ...[
              const SizedBox(height: 8),
              Text(
                '${selectedSurah.ayahCount} ayat akan diputar berurutan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(selection),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Mulai memutar'),
            ),
          ],
        ),
      ),
    );
  }
}
