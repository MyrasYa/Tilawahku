import 'prayer_models.dart';

/// Peristiwa sholat berikutnya beserta sisa waktunya.
class UpcomingPrayer {
  const UpcomingPrayer({
    required this.event,
    required this.remaining,
    this.previous,
  });

  final PrayerEvent event;
  final Duration remaining;

  /// Waktu sholat yang sedang berjalan (jendela sejak `previous` sampai
  /// `event`). `null` bila `now` lebih awal dari semua kejadian yang dikenal.
  final PrayerEvent? previous;

  PrayerKind get kind => event.kind;
}

/// Kejadian sholat terurut, hanya lima waktu.
List<PrayerEvent> sortedSalatEvents(Iterable<PrayerEvent> events) {
  final salat = events.where((event) => event.kind.isSalat).toList();
  salat.sort((a, b) => a.instant.compareTo(b.instant));
  return salat;
}

/// Cari sholat berikutnya dari daftar kejadian yang boleh mencakup beberapa
/// hari. Penggabungan beberapa hari dilakukan pemanggil (layar menggabungkan
/// jadwal hari ini + besok), sehingga pergantian setelah Isya terjadi tanpa
/// logika tanggal di sini.
UpcomingPrayer? nextSalatEvent(
  Iterable<PrayerEvent> events,
  DateTime now,
) {
  final salat = sortedSalatEvents(events);
  for (var index = 0; index < salat.length; index++) {
    final candidate = salat[index];
    final delta = candidate.instant.difference(now);
    if (!delta.isNegative && delta != Duration.zero) {
      return UpcomingPrayer(
        event: candidate,
        remaining: delta,
        previous: index == 0 ? null : salat[index - 1],
      );
    }
  }
  return null;
}

/// Waktu sholat yang sedang berjalan pada `now`.
PrayerEvent? currentSalatEvent(Iterable<PrayerEvent> events, DateTime now) {
  final salat = sortedSalatEvents(events);
  PrayerEvent? running;
  for (final event in salat) {
    if (!event.instant.isAfter(now)) {
      running = event;
    } else {
      break;
    }
  }
  return running;
}

/// True bila semua sholat yang dikenal sudah terlewati: saat itulah jadwal
/// hari berikutnya harus dimuat agar hitung mundur tetap ada.
bool needsFollowingDay(Iterable<PrayerEvent> events, DateTime now) =>
    nextSalatEvent(events, now) == null;

/// Kunci tanggal `yyyy-MM-dd` menurut zona waktu lokasi, bukan perangkat.
/// Perbedaan ini penting untuk lokasi UTC+7 saat perangkat berada di UTC:
/// setengah malam perangkat masih hari yang sama di lokasi.
String dateKeyFor(DateTime instant, Duration locationOffset) {
  final local = instant.toUtc().add(locationOffset);
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Geser kunci tanggal kalender (mis. untuk memuat jadwal besok).
String shiftDateKey(String dateKey, int days) {
  final parts = dateKey.split('-');
  if (parts.length != 3) {
    throw FormatException('Kunci tanggal harus yyyy-MM-dd, dapat $dateKey');
  }
  final base = DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  final shifted = base.add(Duration(days: days));
  return dateKeyFor(shifted, Duration.zero);
}

/// Jam menit detik untuk hitung mundur yang berdenyut tiap detik.
String formatCountdown(Duration remaining) {
  final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(rest)}';
}

/// Durasi dalam bentuk yang bisa dibaca pengguna pada kartu ringkas.
String formatDurationShort(Duration duration) {
  final minutes = duration.isNegative ? 0 : duration.inMinutes;
  if (minutes < 60) return '$minutes menit';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours jam' : '$hours jam $rest menit';
}
