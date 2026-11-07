import 'package:flutter/material.dart';

import '../core/preferences/app_preferences.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/reading/presentation/home_screen.dart';
import 'app_theme.dart';

class TilawahkuApp extends StatefulWidget {
  const TilawahkuApp({super.key});

  @override
  State<TilawahkuApp> createState() => _TilawahkuAppState();
}

class _TilawahkuAppState extends State<TilawahkuApp> {
  final AppPreferences _preferences = const AppPreferences();
  ThemeMode _themeMode = ThemeMode.light;
  bool _themeLoaded = false;
  String? _themeError;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final isDark = await _preferences.darkMode;
      if (!mounted) return;
      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        _themeLoaded = true;
        _themeError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _themeLoaded = true;
        _themeError = error.toString();
      });
    }
  }

  Future<void> _setDarkMode(bool enabled) async {
    await _preferences.setDarkMode(enabled);
    if (!mounted) return;
    setState(() => _themeMode = enabled ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tilawahku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: !_themeLoaded
          ? const _StartupLoadingScreen()
          : _themeError != null
          ? _StartupFailureScreen(
              message: _themeError!,
              onRetry: () {
                setState(() {
                  _themeLoaded = false;
                  _themeError = null;
                });
                _loadTheme();
              },
            )
          : _StartupScreen(
              onSetDarkMode: _setDarkMode,
              preferences: _preferences,
            ),
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _StartupFailureScreen extends StatelessWidget {
  const _StartupFailureScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat preferensi aplikasi: $message',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    ),
  );
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen({
    required this.onSetDarkMode,
    required this.preferences,
  });

  final ValueChanged<bool> onSetDarkMode;
  final AppPreferences preferences;

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _routeFromSplash();
  }

  Future<void> _routeFromSplash() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final onboardingComplete = await widget.preferences.onboardingComplete;
      if (!mounted) return;

      final Widget destination;
      if (!onboardingComplete) {
        destination = OnboardingScreen(
          preferences: widget.preferences,
          onSetDarkMode: widget.onSetDarkMode,
        );
      } else {
        destination = HomeScreen(
          preferences: widget.preferences,
          onSetDarkMode: widget.onSetDarkMode,
        );
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.navy,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/tilawahku_icon.png',
              width: 112,
              height: 112,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const Text(
              'TILAWAHKU',
              style: TextStyle(
                color: AppColors.parchment,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Baca, dengar, dan ulangi dengan tenang',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.parchment),
            ),
            if (_error != null) ...[
              const SizedBox(height: 24),
              Text(
                'Tidak dapat memuat preferensi: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.parchment),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _routeFromSplash,
                child: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
