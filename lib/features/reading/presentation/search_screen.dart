import 'dart:async';

import 'package:flutter/material.dart';

import '../data/reading_repository.dart';
import '../../../core/preferences/app_preferences.dart';
import 'reading_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repository,
    required this.preferences,
  });

  final ReadingRepository repository;
  final AppPreferences preferences;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  QuranSearchFilter _filter = QuranSearchFilter.all;
  Future<List<QuranSearchResult>>? _results;

  void _search(String value) {
    _debounce?.cancel();
    setState(() {
      _query = value.trim();
      _results = null;
    });
    if (_query.isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _results = widget.repository.search(_query, filter: _filter);
      });
    });
  }

  void _selectFilter(QuranSearchFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _results = _query.isEmpty
          ? null
          : widget.repository.search(_query, filter: _filter);
    });
  }

  void _openResult(QuranSearchResult result) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReadingScreen(
          repository: widget.repository,
          preferences: widget.preferences,
          surahNumber: result.ayah.surahNumber,
          startingAyah: result.ayah.ayahNumber,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cari Al-Qur’an')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Cari nama surah atau kata dalam terjemahan',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('Semua', QuranSearchFilter.all),
              _filterChip('Surah', QuranSearchFilter.surah),
              _filterChip('Terjemahan', QuranSearchFilter.translation),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            switch (_filter) {
              QuranSearchFilter.all =>
                'Semua: cari nama surah, teks Arab, atau terjemahan.',
              QuranSearchFilter.surah =>
                'Surah: cari nama surah dalam bahasa Arab atau Indonesia.',
              QuranSearchFilter.translation =>
                'Terjemahan: cari kata atau kalimat dari arti ayat.',
              QuranSearchFilter.arabic =>
                'Semua: cari nama surah, teks Arab, atau terjemahan.',
            },
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(child: _buildResults()),
      ],
    ),
  );

  Widget _filterChip(String label, QuranSearchFilter filter) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => _selectFilter(filter),
    ),
  );

  Widget _buildResults() {
    if (_query.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Masukkan kata yang ingin dicari, lalu pilih Semua, Surah, '
            'atau Terjemahan untuk mempersempit hasil.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<QuranSearchResult>>(
      future: results,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Pencarian gagal: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = snapshot.data!;
        if (matches.isEmpty) {
          return const Center(child: Text('Tidak ada ayat yang cocok.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final result = matches[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openResult(result),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${result.surah.nameIndonesian} '
                              '${result.ayah.surahNumber}:'
                              '${result.ayah.ayahNumber}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        result.ayah.uthmaniText,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(height: 1.8),
                      ),
                      if (result.ayah.transliteration != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          result.ayah.transliteration!,
                          textDirection: TextDirection.ltr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                      if (result.ayah.indonesianTranslation != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          result.ayah.indonesianTranslation!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
