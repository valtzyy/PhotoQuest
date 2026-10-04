import 'dart:math' as math;

/// Utilitas geografis.
class GeoUtils {
  GeoUtils._();

  /// Jari-jari rata-rata bumi (km).
  static const double earthRadiusKm = 6371.0;

  /// Jarak dua titik di permukaan bumi dengan rumus Haversine (hasil dalam km).
  ///
  ///   a = sin²(Δφ/2) + cos φ1 · cos φ2 · sin²(Δλ/2)
  ///   c = 2 · atan2(√a, √(1−a))
  ///   d = R · c
  ///
  /// φ = lintang (latitude), λ = bujur (longitude), keduanya dalam radian.
  /// Haversine memperhitungkan kelengkungan bumi, sehingga lebih akurat
  /// daripada jarak garis lurus (Pythagoras) pada koordinat derajat.
  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final dPhi = _toRad(lat2 - lat1); // selisih lintang
    final dLambda = _toRad(lon2 - lon1); // selisih bujur

    final a =
        math.pow(math.sin(dPhi / 2), 2) +
        math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLambda / 2), 2);
    final c =
        2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)); // sudut pusat (radian)
    return earthRadiusKm * c;
  }

  static double _toRad(double degree) => degree * math.pi / 180;
}
