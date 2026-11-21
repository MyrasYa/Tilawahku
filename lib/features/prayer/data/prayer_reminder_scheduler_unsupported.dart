import '../domain/prayer_reminder.dart';

/// Dipakai pada platform tanpa notifikasi terjadwal (web, desktop) dan pada
/// pengujian unit. Tidak pernah mengklaim pengingat aktif.
class UnsupportedPrayerReminderScheduler implements PrayerReminderScheduler {
  const UnsupportedPrayerReminderScheduler();

  @override
  bool get supportsPlatform => false;

  @override
  Future<bool> prepare() async => false;

  @override
  Future<void> sync(List<PrayerReminder> reminders) async {}

  @override
  Future<void> clear() async {}
}

PrayerReminderScheduler createPrayerReminderScheduler() =>
    const UnsupportedPrayerReminderScheduler();
