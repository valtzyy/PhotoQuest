import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/core/condition_score.dart';
import 'package:photoquest_app/data/models/weather_info.dart';

DateTime at(String hhmm) => DateTime.parse('2026-10-10T$hhmm:00+07:00');

final day = DayLight(
  date: '2026-10-10',
  sunrise: at('05:21'),
  sunset: at('17:32'),
  goldenMorning: TimeRange(at('05:21'), at('06:21')),
  goldenEvening: TimeRange(at('16:32'), at('17:32')),
);

WeatherInfo info({
  List<HourlyPoint> hourly = const [],
  CurrentWeather? current,
  List<DayLight>? days,
}) => WeatherInfo(
  source: 'live',
  isEstimate: false,
  fetchedAt: at('12:00'),
  current: current,
  days: days ?? [day],
  hourly: hourly,
);

void main() {
  group('Timing cahaya (40), sama dengan backend', () {
    test('di dalam golden hour = 40', () {
      expect(timingPoints(at('17:00'), day), 40);
      expect(timingPoints(at('05:30'), day), 40);
    });

    test('turun linear: 1 jam = 30, 3 jam atau lebih = 10', () {
      expect(timingPoints(at('18:32'), day), 30);
      expect(timingPoints(at('20:32'), day), 10);
      expect(timingPoints(at('23:59'), day), 10);
    });

    test('tengah hari 11:00–14:00 WIB maksimal 10', () {
      expect(timingPoints(at('13:45'), day), 10);
    });
  });

  test('Tutupan awan (30), ideal lanskap 20–60%', () {
    expect(cloudPoints(40), 30);
    expect(cloudPoints(0), 20);
    expect(cloudPoints(80), 17.5);
    expect(cloudPoints(100), 5);
    expect(cloudPoints(150), 5); // dijepit ke 100
  });

  test('Peluang hujan (20) = 20 × (1 − hujan/100)', () {
    expect(rainPoints(0), 20);
    expect(rainPoints(50), 10);
    expect(rainPoints(100), 0);
  });

  test('Label sesuai batas 80/60/40', () {
    expect(conditionLabel(80), 'Sangat Baik');
    expect(conditionLabel(79), 'Baik');
    expect(conditionLabel(60), 'Baik');
    expect(conditionLabel(59), 'Cukup');
    expect(conditionLabel(40), 'Cukup');
    expect(conditionLabel(39), 'Kurang');
  });

  group('conditionScoreNow', () {
    test('kondisi ideal = 100 Sangat Baik', () {
      final s = conditionScoreNow(
        info(hourly: [HourlyPoint(at('17:00'), 40, 0)]),
        at('17:00'),
      )!;
      expect(s.score, 100);
      expect(s.label, 'Sangat Baik');
    });

    test('kondisi buruk: (10 + 5 + 2) / 90 = 19 Kurang', () {
      final s = conditionScoreNow(
        info(hourly: [HourlyPoint(at('12:30'), 100, 90)]),
        at('12:30'),
      )!;
      expect(s.score, 19);
      expect(s.label, 'Kurang');
    });

    test('tanpa prakiraan per jam: awan dari current, hujan default 20', () {
      final s = conditionScoreNow(
        info(
          current: CurrentWeather(
            time: at('17:00'),
            temperature: 27,
            cloudCover: 40,
            weatherCode: 2,
            description: 'Berawan',
          ),
        ),
        at('17:00'),
      )!;
      // 40 + 30 + 16 = 86 -> 86/90*100 = 95,6 -> 96
      expect(s.score, 96);
    });

    test(
      'tanpa data cuaca sama sekali: awan 50, hujan 20 (default backend)',
      () {
        final s = conditionScoreNow(info(), at('17:00'))!;
        // 40 + 30 + 16 = 86 -> 96
        expect(s.score, 96);
      },
    );

    test('tanpa data matahari hari ini -> null', () {
      expect(conditionScoreNow(info(days: const []), at('17:00')), isNull);
    });
  });
}
