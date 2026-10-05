import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:photoquest_app/core/sensor_math.dart';
import 'package:photoquest_app/providers/sensor_provider.dart';
import 'package:photoquest_app/ui/screens/level_stabilizer_screen.dart';
import 'package:photoquest_app/ui/widgets/sensor_widgets.dart';

const g = 9.81;

AccelerometerEvent accel(double x, double y, double z) =>
    AccelerometerEvent(x, y, z, DateTime(2026));
GyroscopeEvent gyro(double x, double y, double z) =>
    GyroscopeEvent(x, y, z, DateTime(2026));

/// Vektor gravitasi saat HP tegak (portrait) diputar [deg] derajat.
AccelerometerEvent uprightTilted(double deg) {
  final r = deg * math.pi / 180;
  return accel(g * math.sin(r), g * math.cos(r), 0);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('Rumus roll & pitch', () {
    test('HP tegak lurus portrait -> roll 0°, pitch 90°', () {
      expect(SensorMath.rollDeg(0, g, 0), closeTo(0, 1e-9));
      expect(SensorMath.pitchDeg(0, g, 0), closeTo(90, 1e-9));
    });

    test('HP datar di meja -> roll 0°, pitch 0°', () {
      expect(SensorMath.rollDeg(0, 0, g), closeTo(0, 1e-9));
      expect(SensorMath.pitchDeg(0, 0, g), closeTo(0, 1e-9));
    });

    test('HP tegak diputar 5° -> roll 5°', () {
      final e = uprightTilted(5);
      expect(SensorMath.rollDeg(e.x, e.y, e.z), closeTo(5, 1e-9));
    });

    test('Magnitude gyroscope = √(x²+y²+z²)', () {
      expect(SensorMath.magnitude(0.3, 0.4, 0), closeTo(0.5, 1e-12));
    });
  });

  group('Filter', () {
    test('Low-pass: sampel pertama apa adanya, lalu 0.8·lama + 0.2·baru', () {
      final f = LowPassFilter();
      expect(f.add(10), 10);
      expect(f.add(0), closeTo(8, 1e-12));
      expect(f.add(0), closeTo(6.4, 1e-12));
    });

    test('Moving average hanya memakai 10 sampel terakhir', () {
      final m = MovingAverage(size: 10);
      for (var i = 0; i < 10; i++) {
        m.add(1);
      }
      expect(m.add(1), 1);
      // 9 sampel bernilai 1 + 1 sampel bernilai 11 -> rata-rata 2
      expect(m.add(11), closeTo(2, 1e-12));
    });
  });

  test('Klasifikasi stabilitas sesuai ambang 0.15 dan 0.5 rad/s', () {
    expect(Stability.classify(0.10), Stability.stable);
    expect(Stability.classify(0.15), Stability.slightShake);
    expect(Stability.classify(0.50), Stability.slightShake);
    expect(Stability.classify(0.51), Stability.shaky);
    expect(Stability.shaky.label, 'Try stabilizing your device');
  });

  test('Label level: |roll| ≤ 2° rata, selebihnya miring bertanda', () {
    expect(levelLabel(1.9), 'Rata ✓');
    expect(levelLabel(-2.0), 'Rata ✓');
    expect(levelLabel(3.44), 'Miring +3,4°');
    expect(levelLabel(-5.0), 'Miring -5,0°');
  });

  group('SensorProvider', () {
    late StreamController<AccelerometerEvent> accelCtrl;
    late StreamController<GyroscopeEvent> gyroCtrl;
    late SensorProvider p;

    setUp(() {
      accelCtrl = StreamController<AccelerometerEvent>();
      gyroCtrl = StreamController<GyroscopeEvent>();
      p = SensorProvider(
        accelerometer: () => accelCtrl.stream,
        gyroscope: () => gyroCtrl.stream,
        noDataTimeout: const Duration(milliseconds: 50),
      )..start();
    });

    test(
      'Roll terfilter mendekati kemiringan asli setelah beberapa sampel',
      () async {
        for (var i = 0; i < 40; i++) {
          accelCtrl.add(uprightTilted(10));
        }
        await Future<void>.delayed(Duration.zero);
        expect(p.roll, closeTo(10, 0.01));
        expect(p.isLevelNow, isFalse);
      },
    );

    test('Getaran dirata-rata 10 sampel lalu diklasifikasi', () async {
      for (var i = 0; i < 10; i++) {
        gyroCtrl.add(gyro(0.6, 0, 0));
      }
      await Future<void>.delayed(Duration.zero);
      expect(p.shake, closeTo(0.6, 1e-9));
      expect(p.stability, Stability.shaky);
    });

    test('Error NO_SENSOR -> pesan "tidak tersedia", tidak crash', () async {
      gyroCtrl.addError(
        PlatformException(code: 'NO_SENSOR', message: 'Sensor not found'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(p.gyroError, 'Gyroscope tidak tersedia di HP ini');
    });

    test(
      'Tidak ada data sama sekali -> dianggap tidak tersedia setelah timeout',
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(p.accelError, isNotNull);
      },
    );

    test('dispose() membatalkan subscription stream', () async {
      expect(accelCtrl.hasListener, isTrue);
      p.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(accelCtrl.hasListener, isFalse);
      expect(gyroCtrl.hasListener, isFalse);
    });
  });

  testWidgets(
    'Layar Level: rata -> "Rata ✓", miring -> "Miring", gyro tidak ada -> pesan',
    (tester) async {
      final accelCtrl = StreamController<AccelerometerEvent>.broadcast();
      final gyroCtrl = StreamController<GyroscopeEvent>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          home: LevelStabilizerScreen(
            createSensors: () => SensorProvider(
              accelerometer: () => accelCtrl.stream,
              gyroscope: () => gyroCtrl.stream,
            ),
          ),
        ),
      );

      accelCtrl.add(uprightTilted(0.5));
      gyroCtrl.addError(PlatformException(code: 'NO_SENSOR'));
      await tester.pump();
      expect(find.text('Rata ✓'), findsOneWidget);
      expect(find.text('Gyroscope tidak tersedia di HP ini'), findsOneWidget);

      for (var i = 0; i < 40; i++) {
        accelCtrl.add(uprightTilted(8));
      }
      await tester.pump();
      expect(find.textContaining('Miring +'), findsOneWidget);

      // Tutup layar -> provider di-dispose -> stream tidak didengarkan lagi
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(accelCtrl.hasListener, isFalse);
    },
  );
}
