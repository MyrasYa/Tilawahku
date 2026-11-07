import 'package:flutter/material.dart' hide RepeatMode;

import '../domain/repeat_settings.dart';
import '../../player/data/audio_repository.dart';

class RepeatSettingsScreen extends StatefulWidget {
  const RepeatSettingsScreen({
    super.key,
    required this.tracks,
    required this.currentGlobalAyah,
    this.allowSurahRepeat = true,
    this.allowJuzRepeat = true,
  });

  final List<AudioTrack> tracks;
  final int? currentGlobalAyah;
  final bool allowSurahRepeat;
  final bool allowJuzRepeat;

  @override
  State<RepeatSettingsScreen> createState() => _RepeatSettingsScreenState();
}

class _RepeatSettingsScreenState extends State<RepeatSettingsScreen> {
  RepeatMode _mode = RepeatMode.none;
  int _repeatCount = 3;
  int? _rangeStart;
  int? _rangeEnd;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    if (widget.tracks.isEmpty) return;
    final firstGlobalAyah = widget.tracks.first.globalNumber;
    final hasCurrentAyah = widget.tracks.any(
      (track) => track.globalNumber == widget.currentGlobalAyah,
    );
    _rangeStart = hasCurrentAyah ? widget.currentGlobalAyah : firstGlobalAyah;
    _rangeEnd = _rangeStart;
  }

  void _save() {
    if (widget.tracks.isEmpty) return;
    if (_mode == RepeatMode.range &&
        (_rangeStart == null ||
            _rangeEnd == null ||
            _rangeStart! > _rangeEnd! ||
            widget.currentGlobalAyah == null ||
            widget.currentGlobalAyah! < _rangeStart! ||
            widget.currentGlobalAyah! > _rangeEnd! ||
            !_hasCompleteRange(_rangeStart!, _rangeEnd!))) {
      setState(
        () => _validationError =
            'Pilih rentang lengkap yang mencakup ayat aktif.',
      );
      return;
    }
    Navigator.of(context).pop(
      RepeatSettings(
        mode: _mode,
        repeatCount: _repeatCount,
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
      ),
    );
  }

  bool _hasCompleteRange(int start, int end) {
    final available = widget.tracks.map((track) => track.globalNumber).toSet();
    for (var number = start; number <= end; number++) {
      if (!available.contains(number)) return false;
    }
    return true;
  }

  String _ayahLabel(int globalNumber) {
    final track = widget.tracks.firstWhere(
      (item) => item.globalNumber == globalNumber,
    );
    return '${track.surahName} ${track.surahNumber}:${track.ayahNumber}';
  }

  @override
  Widget build(BuildContext context) {
    final availableAyahs =
        widget.tracks.map((track) => track.globalNumber).toSet().toList()
          ..sort();
    final finiteRepeat =
        _mode != RepeatMode.none && _mode != RepeatMode.unlimited;
    final modeOptions = [
      (
        RepeatMode.none,
        'Tanpa pengulangan',
        'Putar dari ayat aktif hingga akhir antrean.',
      ),
      (
        RepeatMode.ayah,
        'Ulang ayat aktif',
        'Ayat aktif diputar sebanyak N kali, lalu lanjut ke ayat berikutnya.',
      ),
      (
        RepeatMode.range,
        'Ulang rentang ayat',
        'Putar rentang inklusif sebanyak N putaran, lalu lanjut setelah ayat akhir.',
      ),
      if (widget.allowSurahRepeat)
        (
          RepeatMode.surah,
          'Ulang surah',
          'Putar ayat-ayat surah aktif sebanyak N putaran, lalu lanjut setelah surah.',
        ),
      if (widget.allowJuzRepeat)
        (
          RepeatMode.juz,
          'Ulang juz',
          'Putar semua ayat juz aktif berurutan (termasuk lintas surah) sebanyak N putaran.',
        ),
      (
        RepeatMode.unlimited,
        'Ulang tanpa batas',
        'Ulangi seluruh antrean tanpa batas.',
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mode ulang')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.tracks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Antrean audio belum tersedia.'),
              ),
            ),
          RadioGroup<RepeatMode>(
            groupValue: _mode,
            onChanged: (value) {
              if (value != null) setState(() => _mode = value);
            },
            child: Column(
              children: [
                for (final (mode, label, description) in modeOptions)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: RadioListTile<RepeatMode>(
                      value: mode,
                      title: Text(label),
                      subtitle: Text(description),
                    ),
                  ),
              ],
            ),
          ),
          if (finiteRepeat && widget.tracks.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mode == RepeatMode.ayah
                          ? 'Jumlah pemutaran ayat: $_repeatCount'
                          : 'Jumlah putaran total: $_repeatCount',
                    ),
                    if (_mode != RepeatMode.ayah)
                      const Text(
                        'Putaran pertama dimulai dari posisi aktif. Setelah '
                        'putaran terakhir, pemutaran berlanjut setelah scope '
                        'atau berhenti jika scope berada di akhir antrean.',
                      ),
                    Slider(
                      min: 1,
                      max: 100,
                      divisions: 99,
                      value: _repeatCount.toDouble(),
                      label: '$_repeatCount',
                      onChanged: (value) =>
                          setState(() => _repeatCount = value.round()),
                    ),
                  ],
                ),
              ),
            ),
          if (_mode == RepeatMode.range)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _rangeStart,
                      decoration: const InputDecoration(labelText: 'Ayat awal'),
                      items: [
                        for (final number in availableAyahs)
                          DropdownMenuItem(
                            value: number,
                            child: Text(_ayahLabel(number)),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _rangeStart = value;
                        _validationError = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _rangeEnd,
                      decoration: const InputDecoration(
                        labelText: 'Ayat akhir',
                      ),
                      items: [
                        for (final number in availableAyahs)
                          DropdownMenuItem(
                            value: number,
                            child: Text(_ayahLabel(number)),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _rangeEnd = value;
                        _validationError = null;
                      }),
                    ),
                    if (_validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _validationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.tracks.isEmpty ? null : _save,
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }
}
