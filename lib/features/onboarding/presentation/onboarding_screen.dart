import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../reading/presentation/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.preferences,
    required this.onSetDarkMode,
  });

  final AppPreferences preferences;
  final ValueChanged<bool> onSetDarkMode;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _saving = false;

  static const _slides = [
    (
      icon: Icons.menu_book_rounded,
      title: 'Baca dengan tenang',
      detail:
          'Teks Arab, transliterasi Latin, dan terjemahan Indonesia tersedia '
          'secara lokal.',
    ),
    (
      icon: Icons.headphones_rounded,
      title: 'Dengar dan ulangi',
      detail: 'Ikuti murottal ayat demi ayat dengan mode pengulangan.',
    ),
    (
      icon: Icons.wifi_off_rounded,
      title: 'Siap untuk offline',
      detail: 'Unduh audio per juz dan lanjutkan tilawah tanpa internet.',
    ),
  ];

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await widget.preferences.setOnboardingComplete(true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(
            preferences: widget.preferences,
            onSetDarkMode: widget.onSetDarkMode,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan pengaturan: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _saving ? null : _finish,
                  child: const Text('Lewati'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final item = _slides[index];
                    return _OnboardingSlide(
                      icon: item.icon,
                      title: item.title,
                      detail: item.detail,
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _page ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? AppColors.gold
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_page == _slides.length - 1) {
                            _finish();
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                  child: Text(
                    _saving
                        ? 'Menyimpan...'
                        : _page == _slides.length - 1
                        ? 'Mulai'
                        : 'Lanjut',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 152,
            height: 152,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(44),
            ),
            child: Icon(icon, size: 72, color: AppColors.gold),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    ),
  );
}
