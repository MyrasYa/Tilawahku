import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/preferences/app_preferences.dart';
import '../data/reading_repository.dart';
import 'reading_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({
    super.key,
    required this.repository,
    required this.preferences,
  });

  final ReadingRepository repository;
  final AppPreferences preferences;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<AyahEntry>? _bookmarks;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final bookmarks = await widget.repository.getBookmarks();
      if (!mounted) return;
      setState(() {
        _bookmarks = bookmarks;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _reload() {
    setState(() {
      _loading = true;
      _error = null;
    });
    unawaited(_load());
  }

  Future<void> _openBookmark(AyahEntry ayah) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReadingScreen(
          repository: widget.repository,
          preferences: widget.preferences,
          surahNumber: ayah.surahNumber,
          startingAyah: ayah.ayahNumber,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _removeBookmark(AyahEntry ayah) async {
    try {
      await widget.repository.setBookmarked(ayah.globalNumber, false);
      if (mounted) {
        setState(() {
          _bookmarks = _bookmarks
              ?.where((item) => item.globalNumber != ayah.globalNumber)
              .toList();
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus bookmark: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bookmark ayat')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Gagal memuat bookmark: $_error',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          )
        : _bookmarks!.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Belum ada ayat yang disimpan. Tandai ayat saat membaca untuk '
                'menemukannya kembali di sini.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _bookmarks!.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ayah = _bookmarks![index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openBookmark(ayah),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${ayah.surahNameIndonesian ?? 'Surah ${ayah.surahNumber}'}'
                                ' · ${ayah.surahNumber}:${ayah.ayahNumber}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Hapus bookmark',
                              onPressed: () => _removeBookmark(ayah),
                              icon: const Icon(Icons.bookmark_remove_outlined),
                            ),
                          ],
                        ),
                        Text(
                          ayah.uthmaniText,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontFamily: 'AmiriQuran', height: 1.8),
                        ),
                        if (ayah.indonesianTranslation != null) ...[
                          const SizedBox(height: 8),
                          Text(ayah.indonesianTranslation!),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
  );
}
