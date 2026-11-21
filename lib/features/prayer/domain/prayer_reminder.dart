import 'prayer_models.dart';

/// Satu notifikasi pengingat yang akan dijadwalkan pada platform.
class PrayerReminder {
  const PrayerReminder({
    required this.id,
    required this.kind,
    required this.fireAt,
    required this.dateKey,
    required this.timezoneId,
    required this.title,
    required this.body,
  });

  final int id;
  final PrayerKind kind;

  /// Titik waktu mutlak (UTC) saat notifikasi harus muncul.
  final DateTime fireAt;
  final String dateKey;

  /// Zona waktu IANA dari jadwal; dipakai untuk mengirim (jam tangan, nama
  /// zona) yang konsisten ke sistem notifikasi.
  final String timezoneId;
  final String title;
  final String body;
}

/// Port ke sistem notifikasi perangkat. Implementasi per platform ada di
/// `data/prayer_reminder_scheduler*.dart`.
abstract interface class PrayerReminderScheduler {
  bool get supportsPlatform;

  /// Inisialisasi + minta izin yang diperlukan. `false` bila pengguna tidak
  /// bisa menerima pengingat (izin ditolak atau platform tidak didukung).
  Future<bool> prepare();

  /// Mengganti seluruh pengingat tertunda dengan [reminders].
  Future<void> sync(List<PrayerReminder> reminders);

  Future<void> clear();
}

/// Kebijakan penjadwalan pengingat: murni, tanpa plugin, supaya bisa diuji.
class PrayerReminderPolicy {
  const PrayerReminderPolicy._();

  /// Menurunkan jadwal harian menjadi daftar pengingat yang masih akan datang.
  ///
  /// Pengingat yang sudah lewat dari [now] dibuang (bukan dijadwalkan mundur),
  /// dan [leadMinutes] dijepit ke rentang yang masih masuk akal agar tidak
  /// jatuh di hari berikutnya. [kinds] kosong berarti semua waktu salat.
  static List<PrayerReminder> plan({
    required PrayerDaySchedule schedule,
    required Set<PrayerKind> kinds,
    required int leadMinutes,
    required DateTime now,
    String? locationName,
  }) {
    final lead = leadMinutes.clamp(1, PrayerSettings.maxLeadMinutes);
    final utcNow = now.toUtc();
    final selected = kinds.isEmpty
        ? {
            for (final kind in PrayerKind.values)
              if (kind.isSalat) kind,
          }
        : kinds;
    final reminders = <PrayerReminder>[];
    for (final event in schedule.salatEvents) {
      if (!selected.contains(event.kind)) continue;
      final fireAt = event.instant.subtract(Duration(minutes: lead));
      if (!fireAt.isAfter(utcNow)) continue;
      reminders.add(
        PrayerReminder(
          id: notificationId(dateKey: schedule.dateKey, kind: event.kind),
          kind: event.kind,
          fireAt: fireAt,
          dateKey: schedule.dateKey,
          timezoneId: schedule.timezoneId,
          title: 'Pengingat ${event.kind.labelId}',
          body: _body(event, lead, locationName),
        ),
      );
    }
    reminders.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return reminders;
  }

  /// Id stabil untuk (tanggal, waktu sholat) supaya rencana yang dijalankan
  /// dua kali tidak menumpuk entri ganda di sistem.
  static int notificationId({
    required String dateKey,
    required PrayerKind kind,
  }) {
    final compact = int.tryParse(dateKey.replaceAll('-', ''));
    if (compact == null) return 1000 + kind.index;
    return compact * 10 + kind.index + 1;
  }

  static String _body(PrayerEvent event, int lead, String? locationName) {
    final location = locationName == null ? '' : ' • $locationName';
    return '${event.kind.labelId} ${event.wallClock}$location — $lead menit lagi';
  }
}
