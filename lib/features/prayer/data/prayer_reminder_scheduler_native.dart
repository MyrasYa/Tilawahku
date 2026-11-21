import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/prayer_reminder.dart';

/// Saluran notifikasi khusus pengingat waktu salat (berbeda dari notifikasi
/// pemutar audio, yang dikelola `audio_service`).
const String prayerReminderChannelId = 'tilawahku_prayer_times';
const String prayerReminderChannelName = 'Pengingat waktu salat';
const String prayerReminderChannelDescription =
    'Notifikasi beberapa menit sebelum waktu salat tiba.';

class NotificationPrayerReminderScheduler implements PrayerReminderScheduler {
  NotificationPrayerReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _titlePrefix = 'Pengingat ';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  @override
  bool get supportsPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  @override
  Future<bool> prepare() async {
    if (!supportsPlatform) return false;
    if (!_ready) {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              prayerReminderChannelId,
              prayerReminderChannelName,
              description: prayerReminderChannelDescription,
              importance: Importance.high,
            ),
          );
      _ready = true;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      if (granted == false) return false;
      // Izin alarm presisi boleh ditolak: mode inexact tetap menampilkan
      // pengingat, hanya jamnya bisa meleset beberapa menit.
      await android.requestExactAlarmsPermission();
      return true;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted != false;
    }
    return false;
  }

  @override
  Future<void> sync(List<PrayerReminder> reminders) async {
    if (!supportsPlatform) return;
    await _plugin.cancelAllPendingNotifications();
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: zonedFromUtc(reminder.fireAt, reminder.timezoneId),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            prayerReminderChannelId,
            prayerReminderChannelName,
            channelDescription: prayerReminderChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> clear() async {
    if (!supportsPlatform) return;
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final title = request.title ?? '';
      if (title.startsWith(_titlePrefix)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }
}

PrayerReminderScheduler createPrayerReminderScheduler() =>
    NotificationPrayerReminderScheduler();

/// Zona waktu jadwal dipakai agar pasangan (jam tangan, nama zona) yang dikirim
/// ke sistem konsisten; `UTC` menjadi fallback yang tetap menghasilkan instan
/// yang sama ketika nama zona tidak dikenal oleh basis data timezone.
tz.TZDateTime zonedFromUtc(DateTime instantUtc, String timezoneId) {
  tz.Location location;
  try {
    location = tz.getLocation(timezoneId);
  } on Object {
    location = tz.UTC;
  }
  return tz.TZDateTime.from(instantUtc.toUtc(), location);
}
