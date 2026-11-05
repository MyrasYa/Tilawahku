import 'package:flutter/material.dart';

import '../../../core/preferences/app_preferences.dart';
import '../../about/presentation/about_screen.dart';
import '../../download/presentation/download_screen.dart';
import '../../voices/presentation/voice_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.preferences,
    required this.onSetDarkMode,
  });

  final AppPreferences preferences;
  final ValueChanged<bool> onSetDarkMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _translationVisible = true;
  double _textScale = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final darkMode = await widget.preferences.darkMode;
      final translationVisible = await widget.preferences.translationVisible;
      final textScale = await widget.preferences.arabicTextScale;
      if (!mounted) return;
      setState(() {
        _darkMode = darkMode;
        _translationVisible = translationVisible;
        _textScale = textScale;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _saveDarkMode(bool value) async {
    setState(() => _darkMode = value);
    try {
      await widget.preferences.setDarkMode(value);
      widget.onSetDarkMode(value);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Gagal menyimpan tema: $error');
      }
    }
  }

  Future<void> _saveTranslation(bool value) async {
    setState(() => _translationVisible = value);
    try {
      await widget.preferences.setTranslationVisible(value);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Gagal menyimpan preferensi terjemahan: $error');
      }
    }
  }

  Future<void> _saveTextScale(double value) async {
    setState(() => _textScale = value);
    try {
      await widget.preferences.setArabicTextScale(value);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Gagal menyimpan ukuran teks: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _darkMode,
                  title: const Text('Mode gelap'),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  onChanged: _saveDarkMode,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _translationVisible,
                  title: const Text('Tampilkan terjemahan'),
                  secondary: const Icon(Icons.translate_rounded),
                  onChanged: _saveTranslation,
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ukuran teks Arab',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _textScale,
                    min: 0.8,
                    max: 1.8,
                    divisions: 10,
                    label: '${(_textScale * 100).round()}%',
                    onChanged: _saveTextScale,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: const Text('Ganti suara'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      builder: (_) => VoiceSelectionScreen(
                        preferences: widget.preferences,
                        onSetDarkMode: widget.onSetDarkMode,
                        allowBack: true,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Kelola unduhan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => DownloadScreen(
                        preferences: widget.preferences,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Tentang & Sumber'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
