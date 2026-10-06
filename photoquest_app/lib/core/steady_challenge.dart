import 'dart:math' as math;

import 'sensor_math.dart';

/// Logika Steady Shot Challenge (tanpa UI, mudah diuji).
///
/// Aturan: tahan HP dengan |roll| ≤ 2° DAN getaran gyroscope < 0.15 rad/s
/// secara TERUS-MENERUS selama 5 detik, dalam batas waktu 20 detik.
/// Jika salah satu syarat terlanggar, hitungan tahan kembali ke 0.
///
/// Waktu dihitung dalam milidetik bulat agar tidak ada galat pembulatan
/// (mis. 50 × 0,1 detik = 4,9999…).
class SteadyChallenge {
  static const holdTargetMs = 5000;
  static const timeLimitMs = 20000;
  static const shakeLimit = 0.15;

  int elapsedMs = 0;
  int currentHoldMs = 0;
  int bestHoldMs = 0;
  bool success = false;
  bool finished = false;

  double _tiltSum = 0;
  double _shakeSum = 0;
  int _samples = 0;

  /// Satu sampel sensor setelah [dtMs] milidetik.
  void tick({required double roll, required double shake, required int dtMs}) {
    if (finished) return;
    elapsedMs += dtMs;
    _tiltSum += roll.abs();
    _shakeSum += shake;
    _samples++;

    final steady = isLevel(roll) && shake < shakeLimit;
    currentHoldMs = steady
        ? currentHoldMs + dtMs
        : 0; // reset jika keluar batas
    bestHoldMs = math.max(bestHoldMs, currentHoldMs);

    if (currentHoldMs >= holdTargetMs) {
      success = true;
      finished = true;
    } else if (elapsedMs >= timeLimitMs) {
      finished = true;
    }
  }

  /// Kemajuan progress ring (0–1).
  double get progress => (currentHoldMs / holdTargetMs).clamp(0.0, 1.0);

  int get remainingMs => math.max(0, timeLimitMs - elapsedMs);

  double get bestHoldSeconds => bestHoldMs / 1000;

  /// Rata-rata |roll| (derajat) selama challenge.
  double get avgTilt => _samples == 0 ? 0 : _tiltSum / _samples;

  /// Rata-rata magnitude gyroscope (rad/s) selama challenge.
  double get avgShake => _samples == 0 ? 0 : _shakeSum / _samples;
}
