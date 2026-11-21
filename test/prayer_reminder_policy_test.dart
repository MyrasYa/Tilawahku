import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/prayer/domain/prayer_method.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';
import 'package:tilawahku/features/prayer/domain/prayer_reminder.dart';

/// Kebijakan penjadwalan diuji terpisah dari plugin: yang menentukan kapan
/// pengingat boleh ada adalah domain, bukan `flutter_local_notifications`.
void main() {
  const offset = Duration(hours: 7);

  PrayerDaySchedule schedule({DateTime? fetchedAt}) => PrayerDaySchedule(
    dateKey: '2026-11-20',
    timezoneId: 'Asia/Jakarta',
    locationOffset: offset,
    methodId: 20,
    asrMadhab: AsrMadhab.standard,
    events: [
      for (final entry in const {
        PrayerKind.fajr: '04:03',
        PrayerKind.sunrise: '05:26',
        PrayerKind.dhuhr: '11:38',
        PrayerKind.asr: '15:02',
        PrayerKind.maghrib: '17:51',
        PrayerKind.isha: '19:05',
      }.entries)
        PrayerEvent(
          kind: entry.key,
          instant: DateTime.parse('2026-11-20T${entry.value}:00+07:00').toUtc(),
          locationOffset: offset,
        ),
    ],
    source: ScheduleSource.live,
    fetchedAt: fetchedAt,
  );

  List<PrayerReminder> plan({
    required DateTime now,
    Set<PrayerKind> kinds = const {},
    int lead = 10,
    String? locationName,
  }) => PrayerReminderPolicy.plan(
    schedule: schedule(),
    kinds: kinds,
    leadMinutes: lead,
    now: now,
    locationName: locationName,
  );

  test('pengingat yang sudah lewat tidak dijadwalkan mundur', () {
    // 2026-11-20 09:00 UTC = 16:00 WIB: Subuh sampai Asar sudah lewat.
    final reminders = plan(now: DateTime.utc(2026, 11, 20, 9));
    expect(reminders.map((reminder) => reminder.kind), [
      PrayerKind.maghrib,
      PrayerKind.isha,
    ]);
    expect(
      reminders.every(
        (reminder) => reminder.fireAt.isAfter(DateTime.utc(2026, 11, 20, 9)),
      ),
      isTrue,
    );
  });

  test('lead menit dipakai pada instan absolut, bukan jam tangan', () {
    final reminders = plan(now: DateTime.utc(2026, 11, 19, 20), lead: 10);
    // Subuh 04:03+07 = 21:03Z -> pengingat 20:53Z.
    expect(reminders.first.kind, PrayerKind.fajr);
    expect(reminders.first.fireAt, DateTime.utc(2026, 11, 19, 20, 53));
  });

  test('lead dijepit ke rentang yang masih masuk akal', () {
    expect(
      plan(now: DateTime.utc(2026, 11, 19, 20), lead: 0).first.fireAt,
      DateTime.utc(2026, 11, 19, 21, 2),
    );
    expect(
      plan(now: DateTime.utc(2026, 11, 19, 20), lead: -5).first.fireAt,
      DateTime.utc(2026, 11, 19, 21, 2),
    );
    final clamped = plan(now: DateTime.utc(2026, 11, 19, 20), lead: 999).first;
    expect(clamped.fireAt, DateTime.utc(2026, 11, 19, 20, 3));
    expect(
      clamped.body,
      contains('${PrayerSettings.maxLeadMinutes} menit lagi'),
    );
  });

  test('tanpa pilihan waktu, semua waktu sholat diingatkan dan terurut', () {
    final reminders = plan(now: DateTime.utc(2026, 11, 19, 20));
    expect(reminders.map((reminder) => reminder.kind), [
      PrayerKind.fajr,
      PrayerKind.dhuhr,
      PrayerKind.asr,
      PrayerKind.maghrib,
      PrayerKind.isha,
    ]);
    for (var index = 1; index < reminders.length; index++) {
      expect(
        reminders[index].fireAt.isAfter(reminders[index - 1].fireAt),
        isTrue,
      );
    }
  });

  test('Syuruk tidak pernah diingatkan meski diminta', () {
    final reminders = plan(
      now: DateTime.utc(2026, 11, 19, 20),
      kinds: {PrayerKind.sunrise, PrayerKind.dhuhr},
    );
    expect(reminders.map((reminder) => reminder.kind), [PrayerKind.dhuhr]);
  });

  test('judul dan isi menyebut waktu, lokasi, dan sisa menit', () {
    final reminder = plan(
      now: DateTime.utc(2026, 11, 19, 20),
      lead: 5,
      locationName: 'Jakarta',
    ).first;
    expect(reminder.title, 'Pengingat Subuh');
    expect(reminder.body, 'Subuh 04:03 • Jakarta — 5 menit lagi');
    expect(reminder.timezoneId, 'Asia/Jakarta');
    expect(reminder.dateKey, '2026-11-20');
  });

  test('isi tanpa nama lokasi tidak menyisakan pemisah', () {
    expect(
      plan(now: DateTime.utc(2026, 11, 19, 20)).first.body,
      isNot(contains('•')),
    );
  });

  test('id notifikasi stabil dan berbeda per waktu sholat', () {
    final reminders = plan(now: DateTime.utc(2026, 11, 19, 20));
    expect(reminders.map((reminder) => reminder.id).toSet(), hasLength(5));
    expect(
      reminders.first.id,
      PrayerReminderPolicy.notificationId(
        dateKey: '2026-11-20',
        kind: PrayerKind.fajr,
      ),
    );
    expect(reminders.first.id, 202611201);
    // Rencana kedua untuk hari yang sama menghasilkan id yang sama sehingga
    // entri tidak menumpuk di sistem.
    expect(
      plan(now: DateTime.utc(2026, 11, 19, 20)).map((r) => r.id),
      reminders.map((r) => r.id),
    );
  });

  test('kunci tanggal rusak tetap memberi id yang sah', () {
    final fallback = PrayerReminderPolicy.notificationId(
      dateKey: 'bukan-tanggal',
      kind: PrayerKind.asr,
    );
    expect(fallback, 1000 + PrayerKind.asr.index);
    expect(fallback, greaterThan(0));
  });

  test('menit terakhir setelah Isya berarti tidak ada pengingat tersisa', () {
    expect(plan(now: DateTime.utc(2026, 11, 20, 12, 30)), isEmpty);
  });
}
