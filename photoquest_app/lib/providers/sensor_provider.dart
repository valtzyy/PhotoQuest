import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/sensor_math.dart';

/// Membaca accelerometer (level/tilt) dan gyroscope (stabilitas) secara live.
///
/// Dibuat per layar (Level & Stabilizer, Steady Challenge) lewat
/// ChangeNotifierProvider(create: ...), sehingga [dispose] otomatis dipanggil
/// saat layar ditutup -> semua StreamSubscription dibatalkan (hemat baterai).
class SensorProvider extends ChangeNotifier {
  SensorProvider({
    Stream<AccelerometerEvent> Function()? accelerometer,
    Stream<GyroscopeEvent> Function()? gyroscope,
    this.noDataTimeout = const Duration(seconds: 3),
  }) : _accelSource =
           accelerometer ??
           (() => accelerometerEventStream(
             samplingPeriod: SensorInterval.gameInterval,
           )),
       _gyroSource =
           gyroscope ??
           (() => gyroscopeEventStream(
             samplingPeriod: SensorInterval.gameInterval,
           ));

  final Stream<AccelerometerEvent> Function() _accelSource;
  final Stream<GyroscopeEvent> Function() _gyroSource;
  final Duration noDataTimeout;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _accelWatchdog;
  Timer? _gyroWatchdog;

  final _rollFilter = LowPassFilter(alpha: 0.2);
  final _pitchFilter = LowPassFilter(alpha: 0.2);
  final _shakeAverage = MovingAverage(size: 10);

  /// Roll terfilter (derajat). Positif/negatif = arah miring.
  double roll = 0;
  double pitch = 0;

  /// Magnitude gyroscope rata-rata 10 sampel (rad/s).
  double shake = 0;

  bool hasAccelData = false;
  bool hasGyroData = false;
  String? accelError;
  String? gyroError;

  bool get isLevelNow => isLevel(roll);
  Stability get stability => Stability.classify(shake);

  bool get running => _accelSub != null || _gyroSub != null;

  void start() {
    if (running) return;

    _accelSub = _accelSource().listen(
      (e) {
        _accelWatchdog?.cancel();
        // 1) hitung sudut dari vektor gravitasi, 2) haluskan dengan low-pass filter
        roll = _rollFilter.add(SensorMath.rollDeg(e.x, e.y, e.z));
        pitch = _pitchFilter.add(SensorMath.pitchDeg(e.x, e.y, e.z));
        hasAccelData = true;
        notifyListeners();
      },
      onError: (Object e) {
        accelError = _describe(e, 'Accelerometer');
        notifyListeners();
      },
    );

    _gyroSub = _gyroSource().listen(
      (e) {
        _gyroWatchdog?.cancel();
        shake = _shakeAverage.add(SensorMath.magnitude(e.x, e.y, e.z));
        hasGyroData = true;
        notifyListeners();
      },
      onError: (Object e) {
        gyroError = _describe(e, 'Gyroscope');
        notifyListeners();
      },
    );

    // Jika tidak ada data sama sekali dalam beberapa detik -> anggap sensor tidak tersedia.
    _accelWatchdog = Timer(noDataTimeout, () {
      if (!hasAccelData && accelError == null) {
        accelError = 'Accelerometer tidak mengirim data';
        notifyListeners();
      }
    });
    _gyroWatchdog = Timer(noDataTimeout, () {
      if (!hasGyroData && gyroError == null) {
        gyroError = 'Gyroscope tidak mengirim data';
        notifyListeners();
      }
    });
  }

  /// Batalkan semua subscription stream sensor.
  Future<void> stop() async {
    _accelWatchdog?.cancel();
    _gyroWatchdog?.cancel();
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
  }

  /// Reset filter (dipakai saat challenge dimulai ulang).
  void resetFilters() {
    _rollFilter.reset();
    _pitchFilter.reset();
    _shakeAverage.reset();
  }

  String _describe(Object error, String sensor) {
    final text = error.toString();
    if (text.contains('NO_SENSOR')) return '$sensor tidak tersedia di HP ini';
    return '$sensor gagal dibaca';
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
