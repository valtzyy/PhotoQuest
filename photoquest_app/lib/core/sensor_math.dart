import 'dart:collection';
import 'dart:math' as math;

/// Rumus & filter sensor (fungsi murni, mudah diuji).
class SensorMath {
  SensorMath._();

  static const double _radToDeg = 180 / math.pi;

  /// Roll (kemiringan kiri-kanan) dalam derajat dari vektor gravitasi accelerometer.
  ///
  ///   roll = atan2(x, √(y² + z²)) × 180/π
  ///
  /// Sumbu Android: x = ke kanan layar, y = ke atas layar, z = keluar layar.
  /// Saat HP tegak (portrait) gravitasi ada di sumbu y; memutar HP ke kiri/kanan
  /// memindahkan sebagian gravitasi ke sumbu x, sehingga roll ≠ 0.
  /// Rumus yang sama juga benar saat HP diletakkan datar (gravitasi di sumbu z),
  /// karena penyebutnya memakai gabungan y dan z.
  static double rollDeg(double x, double y, double z) =>
      math.atan2(x, math.sqrt(y * y + z * z)) * _radToDeg;

  /// Pitch (kemiringan depan-belakang) dalam derajat.
  ///
  ///   pitch = atan2(y, √(x² + z²)) × 180/π
  ///
  /// ≈ 0° saat HP datar di meja, ≈ 90° saat HP tegak lurus (portrait).
  static double pitchDeg(double x, double y, double z) =>
      math.atan2(y, math.sqrt(x * x + z * z)) * _radToDeg;

  /// Besar kecepatan sudut gyroscope (rad/s): √(gx² + gy² + gz²).
  static double magnitude(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);
}

/// Low-pass filter (exponential smoothing):
///   filtered = 0.8 × filtered + 0.2 × raw
/// Meredam getaran kecil/noise accelerometer agar angka derajat tidak "lompat-lompat".
class LowPassFilter {
  LowPassFilter({this.alpha = 0.2});

  /// Bobot nilai baru (0.2 = 20% baru, 80% nilai lama).
  final double alpha;
  double? _value;

  double? get value => _value;

  double add(double raw) {
    final prev = _value;
    // Sampel pertama langsung dipakai agar tidak mulai dari 0.
    _value = prev == null ? raw : (1 - alpha) * prev + alpha * raw;
    return _value!;
  }

  void reset() => _value = null;
}

/// Rata-rata bergerak N sampel terakhir (dipakai untuk magnitude gyroscope).
class MovingAverage {
  MovingAverage({this.size = 10});

  final int size;
  final Queue<double> _window = Queue<double>();
  double _sum = 0;

  double add(double value) {
    _window.addLast(value);
    _sum += value;
    if (_window.length > size) _sum -= _window.removeFirst();
    return _sum / _window.length;
  }

  void reset() {
    _window.clear();
    _sum = 0;
  }
}

/// Tingkat stabilitas berdasarkan magnitude gyroscope (rad/s).
enum Stability {
  stable('Stabil'),
  slightShake('Sedikit goyang'),
  shaky('Try stabilizing your device');

  const Stability(this.label);
  final String label;

  /// < 0.15 stabil; 0.15–0.5 sedikit goyang; > 0.5 goyang.
  static Stability classify(double magnitude) {
    if (magnitude < 0.15) return Stability.stable;
    if (magnitude <= 0.5) return Stability.slightShake;
    return Stability.shaky;
  }
}

/// Batas "rata" untuk level: |roll| ≤ 2°.
const double levelToleranceDeg = 2.0;

bool isLevel(double rollDeg) => rollDeg.abs() <= levelToleranceDeg;
