import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../prayer/data/prayer_repository.dart';
import '../../prayer/presentation/prayer_times_screen.dart';
import '../domain/hijri_models.dart';
import 'hijri_calendar_controller.dart';

class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  late final HijriCalendarController _controller;
  late final PrayerRepository _prayerRepository;

  @override
  void initState() {
    super.initState();
    _prayerRepository = PrayerRepository();
    _controller = HijriCalendarController(prayerRepository: _prayerRepository);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender Hijri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _controller.busy ? null : _controller.refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          switch (_controller.state) {
            case HijriLoadState.loading:
              return const Center(child: CircularProgressIndicator());
            case HijriLoadState.needsLocation:
              return _buildNeedsLocation();
            case HijriLoadState.failed:
              return _buildError();
            case HijriLoadState.ready:
              return _buildCalendar();
          }
        },
      ),
    );
  }

  Widget _buildNeedsLocation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: AppColors.blue),
            const SizedBox(height: 16),
            const Text(
              'Kalender Hijri membutuhkan lokasi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Atur lokasi di menu Waktu Sholat',
              style: TextStyle(color: AppColors.blue),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrayerTimesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Buka Pengaturan Lokasi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.blue),
            const SizedBox(height: 16),
            const Text(
              'Kalender tidak dapat dimuat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _controller.errorMessage ?? 'Terjadi kesalahan',
              style: const TextStyle(color: AppColors.blue),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _controller.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final month = _controller.month;
    if (month == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentDateCard(),
          const SizedBox(height: 16),
          _buildMonthNavigation(),
          const SizedBox(height: 16),
          _buildCalendarGrid(),
          const SizedBox(height: 16),
          _buildSelectedDateDetails(),
          const SizedBox(height: 16),
          _buildIslamicEvents(),
          const SizedBox(height: 16),
          _buildAdjustmentSettings(),
          if (_controller.notice != null) ...[
            const SizedBox(height: 8),
            Text(
              _controller.notice!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentDateCard() {
    final current = _controller.month?.currentHijriDate;
    if (current == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tanggal Hijri Hari Ini',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              current.displayLabel,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              current.arabicLabel,
              style: const TextStyle(
                fontSize: 18,
                fontFamily: 'AmiriQuran',
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${current.weekdayEn} • ${current.gregorianDate}',
              style: const TextStyle(fontSize: 14, color: AppColors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigation() {
    final month = _controller.month;
    if (month == null) return const SizedBox();

    final monthNames = [
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

    return Row(
      children: [
        IconButton(
          onPressed: _controller.busy ? null : _controller.previousMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '${monthNames[month.gregorianMonth - 1]} ${month.gregorianYear}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          onPressed: _controller.busy ? null : _controller.nextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final month = _controller.month;
    if (month == null) return const SizedBox();

    final days = month.days;
    if (days.isEmpty) return const SizedBox();

    // Group by week (7 days)
    final weeks = <List<HijriCalendarDay>>[];
    var currentWeek = <HijriCalendarDay>[];
    for (final day in days) {
      currentWeek.add(day);
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }
    if (currentWeek.isNotEmpty) {
      weeks.add(currentWeek);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Weekday headers
            Row(
              children: const [
                Expanded(child: _WeekdayLabel('Min')),
                Expanded(child: _WeekdayLabel('Sen')),
                Expanded(child: _WeekdayLabel('Sel')),
                Expanded(child: _WeekdayLabel('Rab')),
                Expanded(child: _WeekdayLabel('Kam')),
                Expanded(child: _WeekdayLabel('Jum')),
                Expanded(child: _WeekdayLabel('Sab')),
              ],
            ),
            const Divider(),
            // Calendar days
            ...weeks.map(
              (week) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: week
                      .map(
                        (day) => Expanded(
                          child: _CalendarDayTile(
                            day: day,
                            isSelected: _controller.selectedDay == day,
                            onTap: () => _controller.selectDay(day),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDateDetails() {
    final selected = _controller.selectedDay;
    if (selected == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tanggal Terpilih',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selected.displayLabel,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selected.arabicLabel,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'AmiriQuran',
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${selected.weekdayEn} • ${selected.gregorianDate}',
              style: const TextStyle(fontSize: 14, color: AppColors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIslamicEvents() {
    final events = IslamicEvents.instance.all;
    if (events.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tanggal Penting Islam',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EventTile(event: event),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Catatan: Tanggal di atas berdasarkan perhitungan. '
              'Tanggal resmi mungkin berbeda sesuai rukyat lokal.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustmentSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penyesuaian Tanggal Hijri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.adjustmentLabel,
              style: const TextStyle(fontSize: 14, color: AppColors.blue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _AdjustmentButton(
                  label: '-2',
                  value: -2,
                  selected: _controller.adjustment.days == -2,
                  onTap: () => _controller.setAdjustment(-2),
                ),
                const SizedBox(width: 8),
                _AdjustmentButton(
                  label: '-1',
                  value: -1,
                  selected: _controller.adjustment.days == -1,
                  onTap: () => _controller.setAdjustment(-1),
                ),
                const SizedBox(width: 8),
                _AdjustmentButton(
                  label: '0',
                  value: 0,
                  selected: _controller.adjustment.days == 0,
                  onTap: () => _controller.setAdjustment(0),
                ),
                const SizedBox(width: 8),
                _AdjustmentButton(
                  label: '+1',
                  value: 1,
                  selected: _controller.adjustment.days == 1,
                  onTap: () => _controller.setAdjustment(1),
                ),
                const SizedBox(width: 8),
                _AdjustmentButton(
                  label: '+2',
                  value: 2,
                  selected: _controller.adjustment.days == 2,
                  onTap: () => _controller.setAdjustment(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  const _CalendarDayTile({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final HijriCalendarDay day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEvent = day.events.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : null,
          borderRadius: BorderRadius.circular(8),
          border: day.isToday
              ? Border.all(color: AppColors.gold, width: 2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(
                day.gregorianDate.split('-')[2],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.parchment : AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.hijriDay}',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppColors.parchment : AppColors.blue,
                ),
              ),
              if (hasEvent)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final IslamicEvent event;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.nameId,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${event.hijriDay} ${_monthNameId(event.hijriMonth)}',
          style: const TextStyle(fontSize: 12, color: AppColors.blue),
        ),
        const SizedBox(height: 2),
        Text(
          event.description,
          style: const TextStyle(fontSize: 12, color: AppColors.blue),
        ),
      ],
    );
  }

  String _monthNameId(int month) {
    const names = [
      'Muharram',
      'Safar',
      'Rabiul Awal',
      'Rabiul Akhir',
      'Jumadil Ula',
      'Jumadil Akhir',
      'Rajab',
      'Sya\'ban',
      'Ramadan',
      'Syawal',
      'Dzulqa\'dah',
      'Dzulhijjah',
    ];
    return month >= 1 && month <= 12 ? names[month - 1] : 'Bulan $month';
  }
}

class _AdjustmentButton extends StatelessWidget {
  const _AdjustmentButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.navy : null,
          foregroundColor: selected ? AppColors.parchment : AppColors.navy,
          side: BorderSide(color: selected ? AppColors.navy : AppColors.blue),
        ),
        child: Text(label),
      ),
    );
  }
}
