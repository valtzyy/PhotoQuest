import 'package:dio/dio.dart';

/// Panggilan langsung HP -> Open-Meteo (tanpa token PhotoQuest).
///
/// Dipakai hanya sebagai cadangan saat backend tidak bisa mengambil cuaca
/// (mis. Open-Meteo membalas 429 karena IP server hosting dipakai bersama).
/// Setiap HP punya IP sendiri sehingga batasnya tidak terbagi dengan server.
class OpenMeteoApi {
  OpenMeteoApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  final Dio _dio;

  static const _url = 'https://api.open-meteo.com/v1/forecast';

  /// JSON mentah Open-Meteo. Parameter sama dengan backend (weatherService.js).
  Future<Map<String, dynamic>> fetch(double lat, double lng) async {
    final res = await _dio.get<Map<String, dynamic>>(
      _url,
      queryParameters: {
        'latitude': lat,
        'longitude': lng,
        'daily': 'sunrise,sunset',
        'hourly': 'cloud_cover,precipitation_probability',
        'current': 'temperature_2m,cloud_cover,weather_code',
        'timezone': 'Asia/Jakarta',
        'forecast_days': 7,
      },
    );
    return res.data!;
  }
}

const _goldenHour = Duration(hours: 1);
const _wibOffsetSeconds = 7 * 3600;

/// Deskripsi kode cuaca WMO (sama dengan backend).
String describeWeatherCode(int code) {
  if (code == 0) return 'Cerah';
  if (code == 1) return 'Cerah berawan';
  if (code == 2) return 'Berawan sebagian';
  if (code == 3) return 'Mendung';
  if (code == 45 || code == 48) return 'Berkabut';
  if (code >= 51 && code <= 57) return 'Gerimis';
  if (code >= 61 && code <= 67) return 'Hujan';
  if (code >= 71 && code <= 77) return 'Salju';
  if (code >= 80 && code <= 82) return 'Hujan lokal';
  if (code >= 95) return 'Badai petir';
  return 'Tidak diketahui';
}

String _two(int v) => v.toString().padLeft(2, '0');

String _offsetString(int seconds) {
  final sign = seconds >= 0 ? '+' : '-';
  final abs = seconds.abs();
  return '$sign${_two(abs ~/ 3600)}:${_two((abs % 3600) ~/ 60)}';
}

/// "2026-10-04T05:21" (waktu lokal Open-Meteo) -> "2026-10-04T05:21:00+07:00"
String _withOffset(String localIso, int offsetSeconds) {
  final base = localIso.length == 16 ? '$localIso:00' : localIso;
  return '$base${_offsetString(offsetSeconds)}';
}

/// Instant -> ISO dengan offset tertentu, mis. "2026-10-04T06:21:00+07:00".
String _toOffsetIso(DateTime t, int offsetSeconds) {
  final shifted = t.toUtc().add(Duration(seconds: offsetSeconds));
  return '${shifted.toIso8601String().substring(0, 19)}'
      '${_offsetString(offsetSeconds)}';
}

/// Ubah respons mentah Open-Meteo menjadi JSON berformat sama dengan
/// GET /weather milik backend (golden hour: sunrise + 60 menit, sunset - 60 menit),
/// sehingga bisa langsung dibaca `WeatherInfo.fromJson` dan disimpan ke cache.
Map<String, dynamic> openMeteoToWeatherJson(
  Map<String, dynamic> raw,
  DateTime now,
) {
  final offset = (raw['utc_offset_seconds'] as num?)?.toInt() ?? _wibOffsetSeconds;
  final daily = raw['daily'] as Map<String, dynamic>;
  final hourly = raw['hourly'] as Map<String, dynamic>;

  final dates = (daily['time'] as List).cast<String>();
  final days = <Map<String, dynamic>>[];
  for (var i = 0; i < dates.length; i++) {
    final sunrise = _withOffset(daily['sunrise'][i] as String, offset);
    final sunset = _withOffset(daily['sunset'][i] as String, offset);
    final sunriseAt = DateTime.parse(sunrise);
    final sunsetAt = DateTime.parse(sunset);
    days.add({
      'date': dates[i],
      'sunrise': sunrise,
      'sunset': sunset,
      'golden_morning': {
        'start': _toOffsetIso(sunriseAt, offset),
        'end': _toOffsetIso(sunriseAt.add(_goldenHour), offset),
      },
      'golden_evening': {
        'start': _toOffsetIso(sunsetAt.subtract(_goldenHour), offset),
        'end': _toOffsetIso(sunsetAt, offset),
      },
    });
  }

  final times = (hourly['time'] as List).cast<String>();
  final hours = <Map<String, dynamic>>[
    for (var i = 0; i < times.length; i++)
      {
        'time': _withOffset(times[i], offset),
        'cloud_cover': hourly['cloud_cover'][i],
        'precipitation_probability': hourly['precipitation_probability'][i],
      },
  ];

  final c = raw['current'] as Map<String, dynamic>?;
  final code = (c?['weather_code'] as num?)?.toInt();
  return {
    'source': 'live',
    'is_estimate': false,
    'fetched_at': now.toUtc().toIso8601String(),
    'timezone': raw['timezone'] ?? 'Asia/Jakarta',
    'current': c == null
        ? null
        : {
            'time': _withOffset(c['time'] as String, offset),
            'temperature': c['temperature_2m'],
            'cloud_cover': c['cloud_cover'],
            'weather_code': code,
            'description': describeWeatherCode(code ?? -1),
          },
    'days': days,
    'hourly': hours,
  };
}
