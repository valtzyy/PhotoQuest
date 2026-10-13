import 'dart:math';

import '../data/models/weather_info.dart';

/// Skor kondisi memotret "sekarang" di lokasi pengguna, untuk kartu Home.
///
/// Porting dari Shoot Condition Score di backend
/// (photoquest_api/src/services/scoreService.js) tanpa komponen kecocokan
/// spot: timing 40 + awan 30 + hujan 20 = 90, lalu diskalakan ke 0–100.
/// Memakai aturan foto lanskap. Jika rumus backend berubah, ubah juga di sini.
class ConditionScore {
  const ConditionScore(this.score, this.label);

  final int score;
  final String label;
}

/// Sama dengan DEFAULT_CLOUD dan DEFAULT_RAIN di photoquest_api/src/routes/ai.js.
const defaultCloud = 50;
const defaultRain = 20;

double _round1(double v) => (v * 10).round() / 10;

/// Jam desimal WIB, mis. 16.5 = 16:30 WIB.
double _wibHour(DateTime t) {
  final w = t.toUtc().add(const Duration(hours: 7));
  return w.hour + w.minute / 60;
}

/// Jarak (jam) dari [t] ke rentang [r]; 0 jika di dalamnya.
double _hoursFromWindow(DateTime t, TimeRange r) {
  if (!t.isBefore(r.start) && !t.isAfter(r.end)) return 0;
  final gap = t.isBefore(r.start) ? r.start.difference(t) : t.difference(r.end);
  return gap.inMilliseconds / Duration.millisecondsPerHour;
}

/// Timing cahaya (maks 40): 40 di golden hour, turun linear sampai 10 saat
/// berjarak 3 jam atau lebih; 11:00–14:00 WIB maksimal 10.
double timingPoints(DateTime t, DayLight day) {
  final distance = min(
    _hoursFromWindow(t, day.goldenMorning),
    _hoursFromWindow(t, day.goldenEvening),
  );
  var score = 40 - 30 * (min(distance, 3.0) / 3);
  final hour = _wibHour(t);
  if (hour >= 11 && hour < 14 && score > 10) score = 10;
  return _round1(score);
}

/// Tutupan awan (maks 30), ideal lanskap 20–60%; awan 100% = 5.
double cloudPoints(num cloud) {
  final c = cloud.clamp(0, 100).toDouble();
  final double score;
  if (c < 20) {
    score = 20 + 10 * (c / 20);
  } else if (c <= 60) {
    score = 30;
  } else {
    score = 30 - 25 * ((c - 60) / 40);
  }
  return _round1(score);
}

/// Peluang hujan (maks 20) = 20 × (1 − hujan/100).
double rainPoints(num rain) =>
    _round1(20 * (1 - rain.clamp(0, 100).toDouble() / 100));

String conditionLabel(int score) {
  if (score >= 80) return 'Sangat Baik';
  if (score >= 60) return 'Baik';
  if (score >= 40) return 'Cukup';
  return 'Kurang';
}

/// Skor untuk [now] dari data cuaca yang sudah dimuat Home.
/// Null bila data matahari hari ini tidak ada.
ConditionScore? conditionScoreNow(WeatherInfo info, DateTime now) {
  final day = info.dayFor(now);
  if (day == null) return null;
  final hour = info.hourAt(now);
  final cloud = hour?.cloudCover ?? info.current?.cloudCover ?? defaultCloud;
  final rain = hour?.precipitationProbability ?? defaultRain;
  final total = timingPoints(now, day) + cloudPoints(cloud) + rainPoints(rain);
  final score = (total / 90 * 100).round();
  return ConditionScore(score, conditionLabel(score));
}
