import 'package:flutter/material.dart';

import '../data/memorization_repository.dart';
import '../domain/memorization_models.dart';
import '../../reading/data/reading_repository.dart';

class MemorizationProgramFormScreen extends StatefulWidget {
  const MemorizationProgramFormScreen({
    super.key,
    required this.repository,
    required this.readingRepository,
  });

  final MemorizationRepository repository;
  final ReadingRepository readingRepository;

  @override
  State<MemorizationProgramFormScreen> createState() =>
      _MemorizationProgramFormScreenState();
}

class _MemorizationProgramFormScreenState
    extends State<MemorizationProgramFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController(text: '5');
  MemorizationScope _scope = MemorizationScope.surah;
  List<Surah>? _surahs;
  int _selectedSurah = 1;
  int _selectedJuz = 1;
  int _startSurah = 1;
  int _startAyah = 1;
  int _endSurah = 1;
  int _endAyah = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    try {
      final surahs = await widget.readingRepository.getSurahs();
      if (mounted) setState(() => _surahs = surahs);
    } catch (error) {
      if (mounted) setState(() => _error = 'Gagal memuat daftar surah: $error');
    }
  }

  Future<(int, int)> _resolveRange() async {
    switch (_scope) {
      case MemorizationScope.surah:
        final ayahs = await widget.readingRepository.getAyahsForSurah(
          _selectedSurah,
        );
        if (ayahs.isEmpty) throw StateError('Data surah belum tersedia.');
        return (ayahs.first.globalNumber, ayahs.last.globalNumber);
      case MemorizationScope.juz:
        final ayahs = await widget.readingRepository.getAyahsForJuz(
          _selectedJuz,
        );
        if (ayahs.isEmpty) throw StateError('Data juz belum tersedia.');
        return (ayahs.first.globalNumber, ayahs.last.globalNumber);
      case MemorizationScope.range:
        final startAyahs = await widget.readingRepository.getAyahsForSurah(
          _startSurah,
        );
        final endAyahs = await widget.readingRepository.getAyahsForSurah(
          _endSurah,
        );
        if (_startAyah > startAyahs.length || _endAyah > endAyahs.length) {
          throw StateError('Nomor ayat berada di luar surah yang dipilih.');
        }
        return (
          startAyahs[_startAyah - 1].globalNumber,
          endAyahs[_endAyah - 1].globalNumber,
        );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (start, end) = await _resolveRange();
      final program = await widget.repository.createProgram(
        name: _nameController.text,
        scope: _scope,
        startGlobalAyah: start,
        endGlobalAyah: end,
        dailyTarget: int.parse(_targetController.text),
      );
      if (mounted) Navigator.of(context).pop(program);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Program tidak dapat disimpan: $error';
        });
      }
    }
  }

  void _selectScope(MemorizationScope? scope) {
    if (scope != null) setState(() => _scope = scope);
  }

  List<DropdownMenuItem<int>> _surahItems(List<Surah> surahs) => surahs
      .map(
        (surah) => DropdownMenuItem(
          value: surah.id,
          child: Text('${surah.id}. ${surah.nameIndonesian}'),
        ),
      )
      .toList(growable: false);

  Widget _surahSelector({
    required String label,
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    final surahs = _surahs;
    if (surahs == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: _surahItems(surahs),
      onChanged: onChanged,
    );
  }

  Widget _ayahSelector({
    required String label,
    required int surahNumber,
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    final surah = _surahs?.firstWhere(
      (item) => item.id == surahNumber,
      orElse: () => _surahs!.first,
    );
    final count = surah?.ayahCount ?? 1;
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$surahNumber'),
      initialValue: value.clamp(1, count),
      decoration: InputDecoration(labelText: label),
      items: [
        for (var ayah = 1; ayah <= count; ayah++)
          DropdownMenuItem(value: ayah, child: Text('$ayah')),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Program hafalan baru')),
    body: _surahs == null && _error == null
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama program (opsional)',
                    hintText: 'Contoh: Juz Amma',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MemorizationScope>(
                  initialValue: _scope,
                  decoration: const InputDecoration(labelText: 'Jenis target'),
                  items: [
                    for (final scope in MemorizationScope.values)
                      DropdownMenuItem(value: scope, child: Text(scope.label)),
                  ],
                  onChanged: _selectScope,
                ),
                const SizedBox(height: 12),
                if (_scope == MemorizationScope.surah)
                  _surahSelector(
                    label: 'Surah',
                    value: _selectedSurah,
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedSurah = value);
                    },
                  ),
                if (_scope == MemorizationScope.juz)
                  DropdownButtonFormField<int>(
                    initialValue: _selectedJuz,
                    decoration: const InputDecoration(labelText: 'Juz'),
                    items: [
                      for (var juz = 1; juz <= 30; juz++)
                        DropdownMenuItem(value: juz, child: Text('Juz $juz')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedJuz = value);
                    },
                  ),
                if (_scope == MemorizationScope.range) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _surahSelector(
                          label: 'Surah awal',
                          value: _startSurah,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _startSurah = value;
                                _startAyah = 1;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ayahSelector(
                          label: 'Ayat',
                          surahNumber: _startSurah,
                          value: _startAyah,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _startAyah = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _surahSelector(
                          label: 'Surah akhir',
                          value: _endSurah,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _endSurah = value;
                                _endAyah = 1;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ayahSelector(
                          label: 'Ayat',
                          surahNumber: _endSurah,
                          value: _endAyah,
                          onChanged: (value) {
                            if (value != null) setState(() => _endAyah = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Rentang dapat melintasi batas surah.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target ayat baru per hari',
                    helperText: 'Ayat yang diulang tidak menambah target.',
                  ),
                  validator: (value) {
                    final target = int.tryParse(value ?? '');
                    if (target == null || target < 1 || target > 6236) {
                      return 'Masukkan target antara 1 dan 6236.';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan program'),
                ),
              ],
            ),
          ),
  );
}
