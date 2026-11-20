import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/prayer_repository.dart';
import '../domain/prayer_countdown.dart';
import '../domain/prayer_models.dart';
import 'prayer_setup_sheets.dart';
import 'prayer_times_controller.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key, this.repository, this.controller});

  /// Disuntikkan dari navigasi agar satu instans repositori dipakai bersama.
  final PrayerRepository? repository;

  /// Hanya untuk pengujian; mengabaikan [repository].
  final PrayerTimesController? controller;

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  late final PrayerTimesController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        PrayerTimesController(repository: widget.repository);
    _controller.addListener(_onChanged);
    _controller.start();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSettings() => showPrayerSettingsSheet(context, _controller);

  Future<void> _pickLocation() => showPrayerLocationSheet(
    context,
    _controller,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Waktu Salat'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang dari server',
          onPressed: _controller.busy ? null : _controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Pengaturan jadwal',
          onPressed: _openSettings,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: switch (_controller.state) {
      PrayerLoadState.needsLocation => _NeedsLocationPanel(
        controller: _controller,
        onPickLocation: _pickLocation,
      ),
      PrayerLoadState.failed when _controller.schedule == null =>
        _FailurePanel(
          message: _controller.errorMessage ?? 'Jadwal tidak tersedia.',
          onRetry: _controller.refresh,
          onPickLocation: _pickLocation,
        ),
      _ => _ScheduleBody(
        controller: _controller,
        onPickLocation: _pickLocation,
        onOpenSettings: _openSettings,
      ),
    },
  );
}

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.controller,
    required this.onPickLocation,
    required this.onOpenSettings,
  });

  final PrayerTimesController controller;
  final VoidCallback onPickLocation;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final schedule = controller.schedule;
    if (schedule == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final upcoming = controller.upcoming;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _HeaderCard(
          schedule: schedule,
          settings: controller.settings,
          upcoming: upcoming,
          countdown: controller.countdownLabel,
          current: controller.currentSalat,
          onChangeLocation: onPickLocation,
        ),
        if (controller.notice != null) ...[
          const SizedBox(height: 12),
          _NoticeCard(message: controller.notice!),
        ],
        const SizedBox(height: 12),
        _DayNavigator(controller: controller),
        const SizedBox(height: 12),
        for (final event in schedule.events)
          _PrayerTile(
            event: event,
            isNext: upcoming?.event.kind == event.kind,
            isRunning: controller.currentSalat?.kind == event.kind,
            adjustment: controller.settings.adjustments.minutesFor(
              event.kind,
            ) ??
            0,
          ),
        const SizedBox(height: 12),
        _ReminderCard(
          controller: controller,
          onOpenSettings: onOpenSettings,
        ),
        if (controller.errorMessage != null) ...[
          const SizedBox(height: 12),
          _NoticeCard(message: controller.errorMessage!),
        ],
        const SizedBox(height: 12),
        Text(
          'Sumber jadwal: AlAdhan API v1 (api.aladhan.com). Waktu dapat '
          'disesuaikan manual di pengaturan. Tanggal Hijriah adalah hasil '
          'perhitungan layanan, bukan penetapan resmi pemerintah.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'WIB/WITA/WIT mengikuti zona waktu lokasi: ${schedule.timezoneId}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _gregorianLabel(String dateKey) {
    final names = const [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    final day = int.tryParse(parts[2]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return dateKey;
    return '$day ${names[month]} ${parts[0]}';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.schedule,
    required this.settings,
    required this.upcoming,
    required this.countdown,
    required this.current,
    required this.onChangeLocation,
  });

  final PrayerDaySchedule schedule;
  final PrayerSettings settings;
  final UpcomingPrayer? upcoming;
  final String countdown;
  final PrayerEvent? current;
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final next = upcoming;
    final theme = Theme.of(context);
    return Card(
      color: AppColors.navy,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onChangeLocation,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: AppColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            settings.location?.name ?? 'Lokasi belum dipilih',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.parchment,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  schedule.hijri?.labelId ?? 'Hijriah tidak tersedia',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_gregorianLabel(schedule.dateKey)} • metode '
              '${settings.method.name} • ${schedule.source.labelId}',
              style: const TextStyle(
                color: AppColors.parchment,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              next == null ? 'Waktu salat hari ini selesai' : 'Menuju ${next.event.kind.labelId}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.parchment,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              next == null ? '--:--:--' : countdown,
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              next == null
                  ? 'Subuh berikutnya ada di jadwal hari besok.'
                  : '${next.event.kind.labelId} pukul ${next.event.wallClock} '
                        '(${_suffixFor(next.remaining)})',
              style: const TextStyle(color: AppColors.parchment),
            ),
            if (current != null) ...[
              const SizedBox(height: 10),
              Text(
                'Sedang berjalan: ${current!.kind.labelId}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _suffixFor(Duration remaining) {
    if (remaining.inHours >= 1) {
      return 'dalam ${formatDurationShort(remaining)}';
    }
    return 'dalam ${remaining.inMinutes} menit';
  }

  static String _gregorianLabel(String dateKey) =>
      _ScheduleBody._gregorianLabel(dateKey);
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({required this.controller});

  final PrayerTimesController controller;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Hari sebelumnya',
            onPressed: controller.previousDay,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(
                    controller.isToday
                        ? 'Hari ini'
                        : _offsetLabel(controller.dayOffset),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    controller.viewedDateKey,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hari berikutnya',
            onPressed: controller.nextDay,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          if (!controller.isToday)
            TextButton(onPressed: controller.backToToday, child: const Text('Hari ini')),
        ],
      ),
    ),
  );

  static String _offsetLabel(int offset) {
    if (offset == 1) return 'Besok';
    if (offset == -1) return 'Kemarin';
    return offset > 0 ? '$offset hari lagi' : '${-offset} hari lalu';
  }
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({
    required this.event,
    required this.isNext,
    required this.isRunning,
    required this.adjustment,
  });

  final PrayerEvent event;
  final bool isNext;
  final bool isRunning;
  final int adjustment;

  @override
  Widget build(BuildContext context) {
    final accent = isNext
        ? AppColors.navy
        : (isRunning ? AppColors.blue : null);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isNext ? AppColors.gold : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          event.kind.isSalat
              ? (isNext ? Icons.mosque_rounded : Icons.schedule_rounded)
              : Icons.wb_sunny_outlined,
          color: accent,
        ),
        title: Text(
          event.kind.labelId,
          style: TextStyle(
            fontWeight: isNext || isRunning ? FontWeight.w800 : FontWeight.w600,
            color: accent,
          ),
        ),
        subtitle: Text(
          event.kind.isSalat
              ? (adjustment == 0
                    ? 'Waktu salat'
                    : 'Disesuaikan ${adjustment > 0 ? '+' : ''}$adjustment menit')
              : 'Bukan waktu salat',
          style: TextStyle(fontSize: 12, color: accent),
        ),
        trailing: Text(
          event.wallClock,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: accent,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.controller, required this.onOpenSettings});

  final PrayerTimesController controller;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final supported = controller.remindersSupportedByPlatform;
    final subtitle = !supported
        ? 'Platform ini tidak mendukung pengingat terjadwal.'
        : !settings.remindersEnabled
        ? 'Belum diaktifkan.'
        : controller.remindersArmed
        ? 'Pengingat dijadwalkan ${settings.reminderLeadMinutes} menit sebelum '
              'waktu salat.'
        : 'Tidak ada pengingat tersisa untuk jadwal yang tampil.';
    return Card(
      child: SwitchListTile(
        value: settings.remindersEnabled && supported,
        onChanged: supported
            ? (value) => controller.setRemindersEnabled(value)
            : null,
        secondary: const Icon(Icons.notifications_active_outlined),
        title: const Text('Pengingat waktu salat'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            if (supported && settings.remindersEnabled)
              TextButton(
                onPressed: onOpenSettings,
                child: const Text('Atur waktu dan daftar pengingat'),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.parchment,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.navy, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NeedsLocationPanel extends StatelessWidget {
  const _NeedsLocationPanel({
    required this.controller,
    required this.onPickLocation,
  });

  final PrayerTimesController controller;
  final VoidCallback onPickLocation;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Icon(Icons.place_outlined, size: 46, color: AppColors.navy),
      const SizedBox(height: 12),
      Text(
        'Tentukan lokasi untuk melihat waktu salat',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'Koordinat hanya dipakai untuk menghitung jadwal pada layanan '
        'AlAdhan dan disimpan di perangkat. Tidak ada riwayat lokasi yang '
        'dikirim.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: controller.busy ? null : controller.useDeviceLocation,
        icon: const Icon(Icons.my_location_rounded),
        label: const Text('Gunakan lokasi perangkat'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: onPickLocation,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Pilih kota atau isi koordinat'),
      ),
      if (controller.locationMessage != null) ...[
        const SizedBox(height: 14),
        _NoticeCard(message: controller.locationMessage!),
      ],
      if (controller.busy) ...[
        const SizedBox(height: 16),
        const Center(child: LinearProgressIndicator()),
      ],
    ],
  );
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({
    required this.message,
    required this.onRetry,
    required this.onPickLocation,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onPickLocation;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 46),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onPickLocation,
            child: const Text('Ganti lokasi'),
          ),
        ],
      ),
    ),
  );
}
