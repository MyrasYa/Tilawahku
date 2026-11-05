import 'package:flutter/material.dart' hide RepeatMode;

import '../domain/repeat_settings.dart';
import '../../player/data/audio_repository.dart';

class RepeatSettingsScreen extends StatefulWidget {
  const RepeatSettingsScreen({
    super.key,
    required this.tracks,
    required this.currentGlobalAyah,
  });

  final List<AudioTrack> tracks;
  final int? currentGlobalAyah;

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
    final firstGlobalAyah = widget.tracks.first.globalNumber;
    final hasCurrentAyah = widget.tracks.any(
      (track) => track.globalNumber == widget.currentGlobalAyah,
    );
    _rangeStart = hasCurrentAyah ? widget.currentGlobalAyah : firstGlobalAyah;
    _rangeEnd = _rangeStart;
  }

  void _save() {
    if (_mode == RepeatMode.range &&
        (_rangeStart == null ||
            _rangeEnd == null ||
            _rangeStart! > _rangeEnd!)) {
      setState(() => _validationError = 'Pilih rentang ayat yang valid.');
      return;
    }
    Navigator.of(context).pop(
      RepeatSettings(
        mode: _mode,
        ayahCount: _repeatCount,
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
      ),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mode ulang')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RadioGroup<RepeatMode>(
            groupValue: _mode,
            onChanged: (value) => setState(() => _mode = value!),
            child: Column(
              children: [
                for (final (mode, label, description) in const [
                  (
                    RepeatMode.none,
                    'Tanpa pengulangan',
                    'Putar dari ayat aktif hingga akhir antrian.',
                  ),
                  (
                    RepeatMode.ayah,
                    'Ulang ayat aktif',
                    'Ulangi ayat yang sedang diputar, lalu lanjutkan.',
                  ),
                  (
                    RepeatMode.range,
                    'Ulang rentang ayat',
                    'Putar berulang hanya pada rentang yang dipilih.',
                  ),
                  (
                    RepeatMode.surah,
                    'Ulang surah',
                    'Putar berulang seluruh surah ayat aktif.',
                  ),
                  (
                    RepeatMode.juz,
                    'Ulang juz',
                    'Putar berulang seluruh juz ayat aktif.',
                  ),
                  (
                    RepeatMode.unlimited,
                    'Ulang tanpa batas',
                    'Putar berulang seluruh antrian yang tersedia.',
                  ),
                ])
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
          if (_mode == RepeatMode.ayah)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jumlah putaran: $_repeatCount'),
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
