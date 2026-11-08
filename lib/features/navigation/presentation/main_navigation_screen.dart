import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../about/presentation/about_screen.dart';
import '../../memorization/data/memorization_repository.dart';
import '../../memorization/domain/memorization_models.dart';
import '../../memorization/presentation/memorization_home_screen.dart';
import '../../reading/data/reading_repository.dart';
import '../../reading/presentation/home_screen.dart';
import '../../reading/presentation/reading_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tajwid/data/tajwid_repository.dart';
import '../../tajwid/presentation/tajwid_home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
    required this.preferences,
    required this.onSetDarkMode,
    this.readingRepository,
    this.memorizationRepository,
    this.tajwidRepository,
  });

  final AppPreferences preferences;
  final ValueChanged<bool> onSetDarkMode;
  final ReadingRepository? readingRepository;
  final MemorizationRepository? memorizationRepository;
  final TajwidRepository? tajwidRepository;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final ReadingRepository _readingRepository;
  late final MemorizationRepository _memorizationRepository;
  late final TajwidRepository _tajwidRepository;
  final ValueNotifier<int> _reloadSignal = ValueNotifier(0);
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _readingRepository = widget.readingRepository ?? ReadingRepository();
    _memorizationRepository =
        widget.memorizationRepository ??
        MemorizationRepository(readingRepository: _readingRepository);
    _tajwidRepository = widget.tajwidRepository ?? TajwidRepository();
  }

  Future<void> _openMemorization() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MemorizationHomeScreen(
        repository: _memorizationRepository,
        readingRepository: _readingRepository,
      ),
    ),
  );

  Future<void> _openTajwid() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => TajwidHomeScreen(
        repository: _tajwidRepository,
        readingRepository: _readingRepository,
      ),
    ),
  );

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          preferences: widget.preferences,
          onSetDarkMode: widget.onSetDarkMode,
        ),
      ),
    );
    if (!mounted) return;
    _reloadSignal.value++;
  }

  Future<void> _openAbout() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));

  @override
  void dispose() {
    _reloadSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        _HomeDashboard(
          preferences: widget.preferences,
          readingRepository: _readingRepository,
          memorizationRepository: _memorizationRepository,
          reloadSignal: _reloadSignal,
          onOpenQuran: () => setState(() => _selectedIndex = 1),
          onOpenMemorization: _openMemorization,
          onOpenTajwid: _openTajwid,
        ),
        HomeScreen(
          preferences: widget.preferences,
          repository: _readingRepository,
          reloadSignal: _reloadSignal,
        ),
        _ActivitiesScreen(
          onOpenMemorization: _openMemorization,
          onOpenTajwid: _openTajwid,
        ),
        _MoreScreen(onOpenSettings: _openSettings, onOpenAbout: _openAbout),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        if (index != _selectedIndex) setState(() => _selectedIndex = index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: 'Al-Qur’an',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome_rounded),
          label: 'Aktivitas',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Lainnya',
        ),
      ],
    ),
  );
}

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({
    required this.preferences,
    required this.readingRepository,
    required this.memorizationRepository,
    required this.reloadSignal,
    required this.onOpenQuran,
    required this.onOpenMemorization,
    required this.onOpenTajwid,
  });

  final AppPreferences preferences;
  final ReadingRepository readingRepository;
  final MemorizationRepository memorizationRepository;
  final ValueListenable<int> reloadSignal;
  final VoidCallback onOpenQuran;
  final VoidCallback onOpenMemorization;
  final VoidCallback onOpenTajwid;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  late Future<_DashboardData> _dashboard;

  @override
  void initState() {
    super.initState();
    _dashboard = _loadDashboard();
    widget.reloadSignal.addListener(_reload);
  }

  @override
  void didUpdateWidget(covariant _HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadSignal == widget.reloadSignal) return;
    oldWidget.reloadSignal.removeListener(_reload);
    widget.reloadSignal.addListener(_reload);
  }

  @override
  void dispose() {
    widget.reloadSignal.removeListener(_reload);
    super.dispose();
  }

  void _reload() => setState(() => _dashboard = _loadDashboard());

  Future<_DashboardData> _loadDashboard() async {
    final voiceId = await widget.preferences.selectedVoiceId;
    final lastRead = voiceId == null
        ? null
        : await widget.readingRepository.getProgress(voiceId);
    final programs = await widget.memorizationRepository.getPrograms();
    var totalProgramAyahs = 0;
    var masteredAyahs = 0;
    var completedToday = 0;
    var targetToday = 0;
    for (final program in programs) {
      totalProgramAyahs += program.totalAyahs;
      final progress = await widget.memorizationRepository.getProgress(
        program.id,
      );
      masteredAyahs += progress.values
          .where((item) => item.status == MemorizationStatus.mastered)
          .length;
      final daily = await widget.memorizationRepository.getDailyProgress(
        program,
      );
      completedToday += daily.completedNewAyahs;
      targetToday += daily.dailyTarget;
    }
    return _DashboardData(
      lastRead: lastRead,
      programCount: programs.length,
      masteredAyahs: masteredAyahs,
      totalProgramAyahs: totalProgramAyahs,
      completedToday: completedToday,
      targetToday: targetToday,
    );
  }

  Future<void> _continueReading(AyahEntry? lastRead) async {
    final ayah = lastRead;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReadingScreen(
          repository: widget.readingRepository,
          preferences: widget.preferences,
          surahNumber: ayah?.surahNumber ?? 1,
          startingAyah: ayah?.ayahNumber ?? 1,
        ),
      ),
    );
    if (mounted) setState(() => _dashboard = _loadDashboard());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Image.asset(
            'assets/branding/tilawahku_icon.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          const Text(
            'Tilawahku',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
    body: FutureBuilder<_DashboardData>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _DashboardMessage(
            icon: Icons.error_outline_rounded,
            message: 'Ringkasan aktivitas tidak dapat dimuat.',
            detail: '${snapshot.error}',
            action: TextButton(
              onPressed: () => setState(() => _dashboard = _loadDashboard()),
              child: const Text('Coba lagi'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              _greeting(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('Lanjutkan perjalanan tilawahmu hari ini.'),
            const SizedBox(height: 18),
            _ContinueReadingCard(
              lastRead: data.lastRead,
              onPressed: () => _continueReading(data.lastRead),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.menu_book_rounded,
                    title: 'Bacaan terakhir',
                    value: data.lastRead == null
                        ? 'Belum ada'
                        : '${data.lastRead!.surahNameIndonesian ?? 'Surah ${data.lastRead!.surahNumber}'} '
                              '${data.lastRead!.surahNumber}:${data.lastRead!.ayahNumber}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.psychology_alt_rounded,
                    title: 'Hafalan dikuasai',
                    value: data.programCount == 0
                        ? 'Belum ada program'
                        : '${data.masteredAyahs} dari ${data.totalProgramAyahs} ayat',
                  ),
                ),
              ],
            ),
            if (data.programCount > 0) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Target hafalan hari ini'),
                  subtitle: Text(
                    '${data.completedToday} dari ${data.targetToday} ayat baru '
                    'di seluruh program',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.schedule_rounded),
                title: Text('Jadwal salat'),
                subtitle: Text('Fitur ini belum tersedia.'),
              ),
            ),
            const SizedBox(height: 20),
            Text('Akses cepat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _DashboardAction(
              icon: Icons.menu_book_rounded,
              title: 'Buka Al-Qur’an',
              subtitle: 'Jelajahi daftar surah dan juz',
              onTap: widget.onOpenQuran,
            ),
            _DashboardAction(
              icon: Icons.psychology_alt_rounded,
              title: 'Program hafalan',
              subtitle: 'Atur target dan tinjau perkembangan',
              onTap: widget.onOpenMemorization,
            ),
            _DashboardAction(
              icon: Icons.auto_awesome_rounded,
              title: 'Belajar Tajwid',
              subtitle: 'Pelajari hukum bacaan dan latihan',
              onTap: widget.onOpenTajwid,
            ),
          ],
        );
      },
    ),
  );

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }
}

class _DashboardData {
  const _DashboardData({
    required this.lastRead,
    required this.programCount,
    required this.masteredAyahs,
    required this.totalProgramAyahs,
    required this.completedToday,
    required this.targetToday,
  });

  final AyahEntry? lastRead;
  final int programCount;
  final int masteredAyahs;
  final int totalProgramAyahs;
  final int completedToday;
  final int targetToday;
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.lastRead, required this.onPressed});

  final AyahEntry? lastRead;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.navy,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
              child: Icon(Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lanjutkan membaca',
                    style: TextStyle(
                      color: AppColors.parchment,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastRead == null
                        ? 'Mulai dari Al-Fatihah'
                        : '${lastRead!.surahNameIndonesian ?? 'Surah ${lastRead!.surahNumber}'} '
                              '${lastRead!.surahNumber}:${lastRead!.ayahNumber}',
                    style: const TextStyle(color: AppColors.parchment),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
          ],
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _ActivitiesScreen extends StatelessWidget {
  const _ActivitiesScreen({
    required this.onOpenMemorization,
    required this.onOpenTajwid,
  });

  final VoidCallback onOpenMemorization;
  final VoidCallback onOpenTajwid;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aktivitas')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Belajar dan ibadah',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _DashboardAction(
          icon: Icons.psychology_alt_rounded,
          title: 'Hafalan Al-Qur’an',
          subtitle: 'Program, latihan, dan progres hafalan',
          onTap: onOpenMemorization,
        ),
        _DashboardAction(
          icon: Icons.history_rounded,
          title: 'Riwayat hafalan',
          subtitle: 'Riwayat tersedia di dalam detail setiap program',
          onTap: onOpenMemorization,
        ),
        _DashboardAction(
          icon: Icons.auto_awesome_rounded,
          title: 'Belajar Tajwid',
          subtitle: 'Materi dan latihan Tajwid',
          onTap: onOpenTajwid,
        ),
        const SizedBox(height: 12),
        const _UnavailableAction(
          icon: Icons.insights_outlined,
          title: 'Statistik membaca',
        ),
        const _UnavailableAction(
          icon: Icons.touch_app_outlined,
          title: 'Tasbih digital',
        ),
        const _UnavailableAction(
          icon: Icons.volunteer_activism_outlined,
          title: 'Doa dan dzikir',
        ),
      ],
    ),
  );
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({required this.onOpenSettings, required this.onOpenAbout});

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lainnya')),
    body: ListView(
      key: const ValueKey('more-options-list'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Fitur tambahan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const _UnavailableAction(
          icon: Icons.schedule_rounded,
          title: 'Jadwal salat',
        ),
        const _UnavailableAction(
          icon: Icons.explore_outlined,
          title: 'Arah kiblat',
        ),
        const _UnavailableAction(
          icon: Icons.calendar_month_outlined,
          title: 'Kalender Hijriah',
        ),
        const _UnavailableAction(
          icon: Icons.star_outline_rounded,
          title: 'Asmaul Husna',
        ),
        const _UnavailableAction(
          icon: Icons.mic_none_rounded,
          title: 'Kajian dan ceramah',
        ),
        const _UnavailableAction(
          icon: Icons.person_outline_rounded,
          title: 'Tokoh Islam',
        ),
        const _UnavailableAction(
          icon: Icons.format_quote_rounded,
          title: 'Quotes dan kisah Islam',
        ),
        const SizedBox(height: 12),
        _DashboardAction(
          icon: Icons.settings_outlined,
          title: 'Pengaturan',
          subtitle: 'Tema, tampilan ayat, suara, dan unduhan',
          onTap: onOpenSettings,
        ),
        _DashboardAction(
          icon: Icons.info_outline_rounded,
          title: 'Tentang aplikasi',
          subtitle: 'Sumber konten dan informasi Tilawahku',
          onTap: onOpenAbout,
        ),
      ],
    ),
  );
}

class _UnavailableAction extends StatelessWidget {
  const _UnavailableAction({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: const Text('Belum tersedia'),
      trailing: const Icon(Icons.lock_outline_rounded),
      enabled: false,
    ),
  );
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.message,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String message;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
