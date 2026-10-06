import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Zona waktu konverter. Memakai database IANA dari package `timezone`
/// (diinisialisasi di main.dart dengan tz.initializeTimeZones()).
///
/// London TIDAK di-hardcode +0: zona Europe/London otomatis memakai
/// GMT (UTC+0) di musim dingin dan BST (UTC+1) saat daylight saving.
class AppZone {
  const AppZone(this.label, this.location);

  final String label; // nama tampilan
  final String location; // ID zona IANA

  tz.Location get tzLocation => tz.getLocation(location);
}

const appZones = [
  AppZone('WIB', 'Asia/Jakarta'), // UTC+7
  AppZone('WITA', 'Asia/Makassar'), // UTC+8
  AppZone('WIT', 'Asia/Jayapura'), // UTC+9
  AppZone('London', 'Europe/London'), // UTC+0 / UTC+1 (BST)
];

class TimeZoneConverter {
  TimeZoneConverter._();

  /// Waktu [instant] (satu titik waktu absolut) dilihat di [zone].
  static tz.TZDateTime inZone(DateTime instant, AppZone zone) =>
      tz.TZDateTime.from(instant, zone.tzLocation);

  /// Jam dinding (tanggal & jam) di [zone] -> titik waktu absolut.
  static tz.TZDateTime fromWallClock(
    AppZone zone,
    DateTime date,
    int hour,
    int minute,
  ) => tz.TZDateTime(
    zone.tzLocation,
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  );

  /// Contoh: "UTC+7", "UTC+1 · BST", "UTC+0 · GMT"
  static String offsetLabel(tz.TZDateTime t, AppZone zone) {
    final minutes = t.timeZoneOffset.inMinutes;
    final sign = minutes >= 0 ? '+' : '-';
    final h = minutes.abs() ~/ 60;
    final m = minutes.abs() % 60;
    final base =
        'UTC$sign$h${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}';
    // Singkatan zona hanya ditampilkan untuk London (GMT/BST).
    return zone.location == 'Europe/London'
        ? '$base · ${t.timeZoneName}'
        : base;
  }

  /// Contoh: "17.32" atau "17.32 (+1 hari)" bila tanggalnya berbeda dari [reference].
  static String clock(tz.TZDateTime t, {DateTime? reference}) {
    final text = DateFormat('HH.mm', 'id_ID').format(t);
    if (reference == null) return text;
    final dayDiff = DateTime(t.year, t.month, t.day)
        .difference(DateTime(reference.year, reference.month, reference.day))
        .inDays;
    if (dayDiff == 0) return text;
    return '$text (${dayDiff > 0 ? '+' : ''}$dayDiff hari)';
  }
}
