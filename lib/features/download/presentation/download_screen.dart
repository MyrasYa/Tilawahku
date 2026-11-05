import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../voices/data/voice_catalog.dart';
import '../data/surah_audio_repository.dart';
import '../data/audio_download_manager.dart';
import '../data/audio_package_repository.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key, required this.preferences});

  final AppPreferences preferences;

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final VoiceCatalog _catalog = const VoiceCatalog();
  final AudioPackageRepository _packageRepository = AudioPackageRepository();
  final SurahAudioRepository _surahPackageRepository = SurahAudioRepository();
  final AudioDownloadManager _downloadManager = AudioDownloadManager.instance;
  Voice? _selectedVoice;
  List<AudioPackage>? _packages;
  List<SurahAudioPackage>? _surahPackages;
  String? _error;
  String? _surahLoadError;
  bool _loading = true;
  bool _loadingSurahPackages = false;
  bool _reloadingPackages = false;
  Timer? _downloadUiRefresh;

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onDownloadChange);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _surahLoadError = null;
      _surahPackages = null;
      _loadingSurahPackages = false;
    });
    try {
      final voices = await _catalog.load();
      final selectedId = await widget.preferences.selectedVoiceId;
      if (selectedId == null) {
        throw StateError('Pilih suara terlebih dahulu di menu Pengaturan.');
      }
      final voice = voices.firstWhere(
        (item) => item.id == selectedId && item.status == VoiceStatus.active,
        orElse: () => throw StateError(
          'Suara terpilih tidak tersedia atau telah dinonaktifkan.',
        ),
      );
      await _downloadManager.recoverInterruptedDownloads(voice.id);
      final packages = await _packageRepository.getPackages(voice.id);
      if (packages.length != 30) {
        throw StateError(
          'Manifest audio belum lengkap (${packages.length}/30 juz).',
        );
      }
      if (!mounted) return;
      setState(() {
        _selectedVoice = voice;
        _packages = packages;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  void _onDownloadChange() {
    if (!mounted || _downloadUiRefresh?.isActive == true) return;
    _downloadUiRefresh = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {});
      final voice = _selectedVoice;
      final surahPackages = _surahPackages;
      final surahCompleted =
          voice != null &&
          surahPackages != null &&
          surahPackages.any(
            (package) =>
                !package.isComplete &&
                _downloadManager
                        .surahProgressFor(voice.id, package.surahNumber)
                        ?.status ==
                    AudioPackageStatus.complete,
          );
      final juzCompleted =
          voice != null &&
          _packages?.any(
                (package) =>
                    package.status != AudioPackageStatus.complete &&
                    _downloadManager.statusFor(voice.id, package.juz) ==
                        AudioPackageStatus.complete,
              ) ==
              true;
      if (surahCompleted || juzCompleted) {
        unawaited(_reloadPackages());
      }
    });
  }

  Future<void> _loadSurahPackages(Voice voice) async {
    try {
      final packages = await _surahPackageRepository.getPackages(voice.id);
      if (!mounted || _selectedVoice?.id != voice.id) return;
      setState(() {
        _surahPackages = packages;
        _loadingSurahPackages = false;
        _surahLoadError = null;
      });
      final surahCompleted = packages.any(
        (package) =>
            !package.isComplete &&
            _downloadManager
                    .surahProgressFor(voice.id, package.surahNumber)
                    ?.status ==
                AudioPackageStatus.complete,
      );
      final juzCompleted =
          _packages?.any(
            (package) =>
                package.status != AudioPackageStatus.complete &&
                _downloadManager.statusFor(voice.id, package.juz) ==
                    AudioPackageStatus.complete,
          ) ==
          true;
      if (surahCompleted || juzCompleted) {
        unawaited(_reloadPackages());
      }
    } catch (error) {
      if (!mounted || _selectedVoice?.id != voice.id) return;
      setState(() {
        _loadingSurahPackages = false;
        _surahLoadError = error.toString();
      });
    }
  }

  Future<void> _startDownload(AudioPackage package) async {
    final voice = _selectedVoice;
    if (voice == null) return;
    try {
      final totalBytes = package.totalBytes > 0
          ? package.totalBytes
          : await _downloadManager.estimatePackageSize(
              voice: voice,
              juz: package.juz,
            );
      if (!mounted) return;

      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unduh Juz ${package.juz}?'),
          content: Text(
            '${package.totalAyah} ayat · ${_formatBytes(totalBytes)}\n'
            'Audio akan disimpan di perangkat dan dapat diputar offline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unduh'),
            ),
          ],
        ),
      );
      if (shouldDownload != true || !mounted) return;

      unawaited(
        _downloadManager
            .downloadPackage(
              voice: voice,
              juz: package.juz,
              totalBytes: totalBytes,
            )
            .catchError((Object error) {
              if (mounted) {
                _showMessage('Unduhan Juz ${package.juz} gagal: $error');
              }
            }),
      );
    } catch (error) {
      if (mounted) _showMessage('Tidak dapat memulai unduhan: $error');
    }
  }

  Future<void> _deletePackage(AudioPackage package) async {
    final voice = _selectedVoice;
    if (voice == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus audio Juz ${package.juz}?'),
        content: const Text(
          'File audio yang tersimpan untuk juz ini akan dihapus. Ayat yang '
          'sama pada unduhan surah juga akan terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await _downloadManager.deletePackage(voice: voice, juz: package.juz);
      await _reloadPackages();
    } catch (error) {
      if (mounted) _showMessage('Gagal menghapus audio: $error');
    }
  }

  Future<void> _startSurahDownload(SurahAudioPackage package) async {
    final voice = _selectedVoice;
    if (voice == null) return;
    try {
      final totalBytes = await _downloadManager.estimateSurahSize(
        voice: voice,
        surahNumber: package.surahNumber,
      );
      if (!mounted) return;
      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unduh Surah ${package.surahName}?'),
          content: Text(
            '${package.totalAyahs} ayat · ${_formatBytes(totalBytes)}\n'
            'Audio akan disimpan di perangkat dan dapat diputar offline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unduh'),
            ),
          ],
        ),
      );
      if (shouldDownload != true || !mounted) return;

      unawaited(
        _downloadManager
            .downloadSurah(
              voice: voice,
              surahNumber: package.surahNumber,
              totalBytes: totalBytes,
            )
            .catchError((Object error) {
              if (mounted) {
                _showMessage(
                  'Unduhan Surah ${package.surahName} gagal: $error',
                );
              }
            }),
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Tidak dapat menyiapkan unduhan Surah ${package.surahName}: $error',
        );
      }
    }
  }

  Future<void> _deleteSurahPackage(SurahAudioPackage package) async {
    final voice = _selectedVoice;
    if (voice == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus audio Surah ${package.surahName}?'),
        content: const Text(
          'File audio surah ini akan dihapus. File ayat yang sama pada '
          'unduhan juz juga akan terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await _downloadManager.deleteSurah(
        voice: voice,
        surahNumber: package.surahNumber,
      );
      await _reloadPackages();
    } catch (error) {
      if (mounted) _showMessage('Gagal menghapus audio surah: $error');
    }
  }

  Future<void> _reloadPackages() async {
    final voice = _selectedVoice;
    if (voice == null || _reloadingPackages) return;
    _reloadingPackages = true;
    try {
      final packages = await _packageRepository.getPackages(voice.id);
      final surahPackages = _surahPackages == null
          ? null
          : await _surahPackageRepository.getPackages(voice.id);
      if (mounted) {
        setState(() {
          _packages = packages;
          if (surahPackages != null) {
            _surahPackages = surahPackages;
            _surahLoadError = null;
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Gagal memuat paket audio: $error');
    } finally {
      _reloadingPackages = false;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onTabSelected(int index) {
    if (index != 1 ||
        _surahPackages != null ||
        _loadingSurahPackages ||
        _surahLoadError != null) {
      return;
    }
    final voice = _selectedVoice;
    if (voice == null) return;
    setState(() => _loadingSurahPackages = true);
    unawaited(_loadSurahPackages(voice));
  }

  @override
  void dispose() {
    _downloadUiRefresh?.cancel();
    _downloadManager.removeListener(_onDownloadChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Unduhan audio'),
        bottom: TabBar(
          onTap: _onTabSelected,
          tabs: [
            Tab(text: 'Juz'),
            Tab(text: 'Surah'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _DownloadMessage(
              message: _error!,
              action: TextButton(
                onPressed: _load,
                child: const Text('Coba lagi'),
              ),
            )
          : _buildPackages(context),
    ),
  );

  Widget _buildPackages(BuildContext context) {
    final voice = _selectedVoice!;
    final packages = _packages!;
    final completeCount = packages
        .where(
          (package) =>
              (_downloadManager.statusFor(voice.id, package.juz) ??
                  package.status) ==
              AudioPackageStatus.complete,
        )
        .length;

    final completeSurahCount = _surahPackages
        ?.where(
          (package) =>
              package.isComplete ||
              _downloadManager
                      .surahProgressFor(voice.id, package.surahNumber)
                      ?.status ==
                  AudioPackageStatus.complete,
        )
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Card(
            color: AppColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.headphones_rounded,
                    size: 36,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voice.name,
                          style: const TextStyle(
                            color: AppColors.parchment,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Audio dapat diunduh berdasarkan juz atau surah. '
                          'Ukuran dan progres unduhan ditampilkan dalam MB.',
                          style: TextStyle(color: AppColors.parchment),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$completeCount/30 juz\n'
                    '${completeSurahCount ?? '—'}/114 surah',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: packages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _PackageCard(
                  package: packages[index],
                  manager: _downloadManager,
                  onStart: () => _startDownload(packages[index]),
                  onPause: () => _downloadManager.pausePackage(
                    voiceId: voice.id,
                    juz: packages[index].juz,
                  ),
                  onCancel: () => _downloadManager.cancelPackage(
                    voiceId: voice.id,
                    juz: packages[index].juz,
                  ),
                  onDelete: () => _deletePackage(packages[index]),
                ),
              ),
              _surahPackages == null
                  ? Center(
                      child: _surahLoadError != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Gagal memuat daftar surah: '
                                    '$_surahLoadError',
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _loadingSurahPackages = true;
                                        _surahLoadError = null;
                                      });
                                      unawaited(_loadSurahPackages(voice));
                                    },
                                    child: const Text('Coba lagi'),
                                  ),
                                ],
                              ),
                            )
                          : _loadingSurahPackages
                          ? const CircularProgressIndicator()
                          : const Text('Daftar surah belum tersedia.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _surahPackages!.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final package = _surahPackages![index];
                        return _SurahPackageCard(
                          package: package,
                          manager: _downloadManager,
                          onStart: () => _startSurahDownload(package),
                          onPause: () => _downloadManager.pauseSurah(
                            voiceId: voice.id,
                            surahNumber: package.surahNumber,
                          ),
                          onDelete: () => _deleteSurahPackage(package),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SurahPackageCard extends StatelessWidget {
  const _SurahPackageCard({
    required this.package,
    required this.manager,
    required this.onStart,
    required this.onPause,
    required this.onDelete,
  });

  final SurahAudioPackage package;
  final AudioDownloadManager manager;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final liveProgress = manager.surahProgressFor(
      package.voiceId,
      package.surahNumber,
    );
    final downloadedAyahs =
        liveProgress?.completedAyahs ?? package.downloadedAyahs;
    final status =
        liveProgress?.status == AudioPackageStatus.downloading ||
            liveProgress?.status == AudioPackageStatus.paused ||
            liveProgress?.status == AudioPackageStatus.failed
        ? liveProgress!.status
        : downloadedAyahs == package.totalAyahs
        ? AudioPackageStatus.complete
        : AudioPackageStatus.notDownloaded;
    final isActive = status == AudioPackageStatus.downloading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.gold,
                  child: Text('${package.surahNumber}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.surahName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '$downloadedAyahs/${package.totalAyahs} ayat diunduh · '
                        '${_formatBytes(liveProgress?.downloadedBytes ?? package.downloadedBytes)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (manager.isEstimatingSurah(
                  package.voiceId,
                  package.surahNumber,
                ))
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isActive)
                  IconButton(
                    tooltip: 'Jeda unduhan surah',
                    onPressed: onPause,
                    icon: const Icon(Icons.pause_rounded),
                  )
                else if (status == AudioPackageStatus.complete)
                  IconButton(
                    tooltip: 'Hapus unduhan surah',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: downloadedAyahs == 0
                            ? 'Unduh surah'
                            : 'Lanjutkan unduhan surah',
                        onPressed: onStart,
                        icon: Icon(
                          downloadedAyahs == 0
                              ? Icons.download_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      if (downloadedAyahs > 0)
                        IconButton(
                          tooltip: 'Hapus audio surah',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                  ),
              ],
            ),
            if (status == AudioPackageStatus.failed &&
                liveProgress?.error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  liveProgress!.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.manager,
    required this.onStart,
    required this.onPause,
    required this.onCancel,
    required this.onDelete,
  });

  final AudioPackage package;
  final AudioDownloadManager manager;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status =
        manager.statusFor(package.voiceId, package.juz) ?? package.status;
    final liveProgress = manager.progressFor(package.voiceId, package.juz);
    final progress = liveProgress?.progress ?? package.progress;
    final downloadedBytes =
        liveProgress?.completedBytes ?? package.downloadedBytes;
    final downloadedAyahs =
        liveProgress?.completedAyahs ?? package.downloadedAyah;
    final totalBytes = liveProgress?.totalBytes ?? package.totalBytes;
    final estimating = manager.isEstimating(package.voiceId, package.juz);
    final isActive = status == AudioPackageStatus.downloading;
    final canStart =
        status == AudioPackageStatus.notDownloaded ||
        status == AudioPackageStatus.paused ||
        status == AudioPackageStatus.failed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.gold,
                  child: Text('${package.juz}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Juz ${package.juz}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '$downloadedAyahs/${package.totalAyah} ayat diunduh · '
                        '${_formatBytes(downloadedBytes)}'
                        '${totalBytes > 0 ? ' dari ${_formatBytes(totalBytes)}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (estimating)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (status == AudioPackageStatus.complete)
                  IconButton(
                    tooltip: 'Hapus unduhan',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                else
                  _PackageActionMenu(
                    status: status,
                    canStart: canStart,
                    hasDownloadedFiles: downloadedAyahs > 0,
                    onStart: onStart,
                    onPause: onPause,
                    onCancel: onCancel,
                    onDelete: onDelete,
                  ),
              ],
            ),
            if (status != AudioPackageStatus.complete &&
                (isActive ||
                    status == AudioPackageStatus.paused ||
                    downloadedAyahs > 0)) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress.clamp(0, 1)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_formatBytes(downloadedBytes)}'
                  '${totalBytes > 0 ? ' / ${_formatBytes(totalBytes)}' : ''}'
                  ' · ${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (status == AudioPackageStatus.failed && package.error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  package.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PackageActionMenu extends StatelessWidget {
  const _PackageActionMenu({
    required this.status,
    required this.canStart,
    required this.hasDownloadedFiles,
    required this.onStart,
    required this.onPause,
    required this.onCancel,
    required this.onDelete,
  });

  final AudioPackageStatus status;
  final bool canStart;
  final bool hasDownloadedFiles;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (canStart) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: status == AudioPackageStatus.notDownloaded
                ? 'Unduh'
                : 'Lanjutkan unduhan',
            onPressed: onStart,
            icon: Icon(
              status == AudioPackageStatus.notDownloaded
                  ? Icons.download_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
          if (hasDownloadedFiles)
            IconButton(
              tooltip: 'Hapus unduhan juz ini',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Aksi paket audio',
      onSelected: (action) {
        if (action == 'pause') onPause();
        if (action == 'cancel') onCancel();
        if (action == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        if (status == AudioPackageStatus.downloading)
          const PopupMenuItem(value: 'pause', child: Text('Jeda')),
        if (status == AudioPackageStatus.downloading)
          const PopupMenuItem(value: 'cancel', child: Text('Batalkan unduhan')),
        if (status == AudioPackageStatus.paused ||
            status == AudioPackageStatus.failed)
          const PopupMenuItem(value: 'delete', child: Text('Hapus file')),
      ],
    );
  }
}

class _DownloadMessage extends StatelessWidget {
  const _DownloadMessage({required this.message, required this.action});

  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.download_for_offline_outlined,
            size: 56,
            color: AppColors.gold,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          action,
        ],
      ),
    ),
  );
}

String _formatBytes(int bytes) {
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
