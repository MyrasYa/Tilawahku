import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/prayer_method.dart';
import '../domain/prayer_models.dart';
import 'prayer_times_controller.dart';

Future<void> showPrayerLocationSheet(
  BuildContext context,
  PrayerTimesController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _LocationSheet(controller: controller),
);

Future<void> showPrayerSettingsSheet(
  BuildContext context,
  PrayerTimesController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SettingsSheet(controller: controller),
);

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({required this.controller});

  final PrayerTimesController controller;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    final location = widget.controller.settings.location;
    if (location != null && location.source == LocationSource.manual) {
      _name.text = location.name;
      _latitude.text = location.latitude.toStringAsFixed(4);
      _longitude.text = location.longitude.toStringAsFixed(4);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _submitManual() async {
    final latitude = double.tryParse(_latitude.text.replaceAll(',', '.'));
    final longitude = double.tryParse(_longitude.text.replaceAll(',', '.'));
    if (latitude == null || longitude == null) {
      setState(() => _error = 'Isi lintang dan bujur sebagai angka.');
      return;
    }
    await widget.controller.enterCoordinates(
      name: _name.text,
      latitude: latitude,
      longitude: longitude,
    );
    if (!mounted) return;
    if (widget.controller.locationMessage != null) {
      setState(() => _error = widget.controller.locationMessage!);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final cities = query.isEmpty
        ? widget.controller.cities
        : widget.controller.cities
              .where(
                (city) =>
                    city.name.toLowerCase().contains(query) ||
                    (city.country?.toLowerCase().contains(query) ?? false),
              )
              .toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atur lokasi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Kota di bawah dibundel dalam aplikasi (koordinat OpenStreetMap, '
              'zona waktu AlAdhan). Pilihan lain bisa diisi manual.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.controller.busy
                  ? null
                  : () async {
                      await widget.controller.useDeviceLocation();
                      if (context.mounted &&
                          widget.controller.locationMessage == null) {
                        Navigator.of(context).pop();
                      }
                    },
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Gunakan lokasi perangkat'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Cari kota',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final city in cities)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_city_rounded),
                      title: Text(city.name),
                      subtitle: Text(
                        '${city.timezoneId ?? 'zona tidak diketahui'} • '
                        '${city.latitude.toStringAsFixed(3)}, '
                        '${city.longitude.toStringAsFixed(3)}',
                      ),
                      onTap: () async {
                        await widget.controller.selectCity(city);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  if (cities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Kota tidak ditemukan dalam daftar lokal.'),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            Text(
              'Koordinat manual',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Nama lokasi',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Lintang',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Bujur',
                    ),
                  ),
                ),
              ],
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submitManual,
                child: const Text('Simpan lokasi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.controller});

  final PrayerTimesController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengaturan jadwal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: settings.method.aladhanId,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Metode perhitungan',
                ),
                items: [
                  for (final method in PrayerMethod.values)
                    DropdownMenuItem(
                      value: method.aladhanId,
                      child: Text('${method.name} • ${method.angleSummary}'),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  controller.selectMethod(PrayerMethod.byId(value));
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Mazhab Asar',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              SegmentedButton<AsrMadhab>(
                segments: [
                  for (final madhab in AsrMadhab.values)
                    ButtonSegment(value: madhab, label: Text(madhab.labelId)),
                ],
                selected: {settings.asrMadhab},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    controller.selectMadhab(value.first),
              ),
              const SizedBox(height: 16),
              Text(
                'Penyesuaian menit',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Text(
                'Hanya mengoreksi tampilan dan pengingat di perangkat; nilai '
                'dari layanan tidak diubah.',
                style: TextStyle(fontSize: 12),
              ),
              for (final kind in PrayerKind.values)
                if (kind.isSalat)
                  _AdjustmentRow(
                    kind: kind,
                    minutes: settings.adjustments.minutesFor(kind) ?? 0,
                    onChanged: (minutes) =>
                        controller.setAdjustment(kind, minutes),
                  ),
              const SizedBox(height: 16),
              Text(
                'Pengingat',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.remindersEnabled,
                onChanged: controller.remindersSupportedByPlatform
                    ? (value) => controller.setRemindersEnabled(value)
                    : null,
                title: const Text('Aktifkan pengingat waktu salat'),
                subtitle: Text(
                  controller.remindersSupportedByPlatform
                      ? (controller.remindersArmed
                            ? 'Terjadwal untuk jadwal yang sedang tampil.'
                            : 'Belum ada pengingat tersisa hari ini.')
                      : 'Tidak tersedia pada platform ini.',
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: settings.reminderLeadMinutes,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Menit sebelum waktu salat',
                ),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 menit')),
                  DropdownMenuItem(value: 5, child: Text('5 menit')),
                  DropdownMenuItem(value: 10, child: Text('10 menit')),
                  DropdownMenuItem(value: 15, child: Text('15 menit')),
                  DropdownMenuItem(value: 20, child: Text('20 menit')),
                  DropdownMenuItem(value: 30, child: Text('30 menit')),
                ],
                onChanged: settings.remindersEnabled
                    ? (value) {
                        if (value != null) controller.setReminderLead(value);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final kind in PrayerKind.values)
                    if (kind.isSalat)
                      FilterChip(
                        label: Text(kind.labelId),
                        selected: settings.reminderKinds.isEmpty ||
                            settings.reminderKinds.contains(kind),
                        onSelected: (_) =>
                            controller.toggleReminderKind(kind),
                      ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Daftar kosong berarti semua waktu salat diingatkan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Peringatan: pengingat terjadwal bergantung pada izin notifikasi '
                'dan izin alarm presisi perangkat. Pada Android, pengujian di '
                'perangkat nyata belum dilakukan.',
                style: TextStyle(fontSize: 12, color: AppColors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({
    required this.kind,
    required this.minutes,
    required this.onChanged,
  });

  final PrayerKind kind;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(kind.labelId)),
      IconButton(
        tooltip: 'Kurangi 1 menit',
        onPressed: () => onChanged((minutes - 1).clamp(
          -PrayerAdjustments.maxMinutes,
          PrayerAdjustments.maxMinutes,
        )),
        icon: const Icon(Icons.remove_rounded),
      ),
      SizedBox(
        width: 52,
        child: Text(
          '${minutes > 0 ? '+' : ''}$minutes',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        tooltip: 'Tambah 1 menit',
        onPressed: () => onChanged((minutes + 1).clamp(
          -PrayerAdjustments.maxMinutes,
          PrayerAdjustments.maxMinutes,
        )),
        icon: const Icon(Icons.add_rounded),
      ),
    ],
  );
}
