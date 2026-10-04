/// Rentang waktu (mis. golden hour).
class TimeRange {
  const TimeRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  factory TimeRange.fromJson(Map<String, dynamic> json) => TimeRange(
    DateTime.parse(json['start'] as String),
    DateTime.parse(json['end'] as String),
  );
}

/// Data matahari satu hari: sunrise, sunset, dan dua jendela golden hour.
class DayLight {
  const DayLight({
    required this.date,
    required this.sunrise,
    required this.sunset,
    required this.goldenMorning,
    required this.goldenEvening,
  });

  final String date; // yyyy-MM-dd (kalender WIB)
  final DateTime sunrise;
  final DateTime sunset;
  final TimeRange goldenMorning;
  final TimeRange goldenEvening;

  factory DayLight.fromJson(Map<String, dynamic> json) => DayLight(
    date: json['date'] as String,
    sunrise: DateTime.parse(json['sunrise'] as String),
    sunset: DateTime.parse(json['sunset'] as String),
    goldenMorning: TimeRange.fromJson(
      json['golden_morning'] as Map<String, dynamic>,
    ),
    goldenEvening: TimeRange.fromJson(
      json['golden_evening'] as Map<String, dynamic>,
    ),
  );
}

class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.temperature,
    required this.cloudCover,
    required this.weatherCode,
    required this.description,
  });

  final DateTime time;
  final double temperature;
  final int cloudCover;
  final int weatherCode;
  final String description;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) => CurrentWeather(
    time: DateTime.parse(json['time'] as String),
    temperature: (json['temperature'] as num).toDouble(),
    cloudCover: (json['cloud_cover'] as num).toInt(),
    weatherCode: (json['weather_code'] as num).toInt(),
    description: json['description'] as String,
  );
}

/// Prakiraan per jam: tutupan awan & peluang hujan (dipakai AI score di Fase 8).
class HourlyPoint {
  const HourlyPoint(this.time, this.cloudCover, this.precipitationProbability);
  final DateTime time;
  final int cloudCover;
  final int precipitationProbability;

  factory HourlyPoint.fromJson(Map<String, dynamic> json) => HourlyPoint(
    DateTime.parse(json['time'] as String),
    (json['cloud_cover'] as num?)?.toInt() ?? 0,
    (json['precipitation_probability'] as num?)?.toInt() ?? 0,
  );
}

/// Respons GET /weather.
class WeatherInfo {
  const WeatherInfo({
    required this.source,
    required this.isEstimate,
    required this.fetchedAt,
    required this.days,
    required this.hourly,
    this.current,
  });

  /// "live" | "cache" | "estimate"
  final String source;
  final bool isEstimate;
  final DateTime fetchedAt;
  final CurrentWeather? current;
  final List<DayLight> days;
  final List<HourlyPoint> hourly;

  factory WeatherInfo.fromJson(Map<String, dynamic> json) => WeatherInfo(
    source: json['source'] as String,
    isEstimate: json['is_estimate'] as bool? ?? false,
    fetchedAt: DateTime.parse(json['fetched_at'] as String),
    current: json['current'] == null
        ? null
        : CurrentWeather.fromJson(json['current'] as Map<String, dynamic>),
    days: (json['days'] as List)
        .map((e) => DayLight.fromJson(e as Map<String, dynamic>))
        .toList(),
    hourly: (json['hourly'] as List)
        .map((e) => HourlyPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Fallback terakhir di aplikasi (server tidak terjangkau & belum ada cache):
  /// sunrise 05:30 dan sunset 17:45 WIB, sama seperti estimasi di backend.
  factory WeatherInfo.estimate(DateTime now) {
    const wib = Duration(hours: 7);
    final days = <DayLight>[];
    for (var i = 0; i < 7; i++) {
      final d = now
          .toUtc()
          .add(wib)
          .add(Duration(days: i)); // tanggal kalender WIB
      DateTime at(int h, int m) =>
          DateTime.utc(d.year, d.month, d.day, h, m).subtract(wib);
      final sunrise = at(5, 30);
      final sunset = at(17, 45);
      days.add(
        DayLight(
          date: '${d.year}-${_two(d.month)}-${_two(d.day)}',
          sunrise: sunrise,
          sunset: sunset,
          goldenMorning: TimeRange(
            sunrise,
            sunrise.add(const Duration(hours: 1)),
          ),
          goldenEvening: TimeRange(
            sunset.subtract(const Duration(hours: 1)),
            sunset,
          ),
        ),
      );
    }
    return WeatherInfo(
      source: 'estimate',
      isEstimate: true,
      fetchedAt: now,
      days: days,
      hourly: const [],
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Data matahari untuk tanggal kalender WIB dari [t].
  DayLight? dayFor(DateTime t) {
    final w = t.toUtc().add(const Duration(hours: 7));
    final key = '${w.year}-${_two(w.month)}-${_two(w.day)}';
    for (final d in days) {
      if (d.date == key) return d;
    }
    return null;
  }

  /// Prakiraan per jam yang paling dekat dengan [t] (maks. selisih 1 jam).
  HourlyPoint? hourAt(DateTime t) {
    HourlyPoint? best;
    var bestDiff = const Duration(hours: 1);
    for (final h in hourly) {
      final diff = h.time.difference(t).abs();
      if (diff <= bestDiff) {
        best = h;
        bestDiff = diff;
      }
    }
    return best;
  }
}
