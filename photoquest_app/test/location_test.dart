import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:photoquest_app/core/formatters.dart';
import 'package:photoquest_app/core/geo_utils.dart';
import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/models/spot.dart';
import 'package:photoquest_app/providers/location_provider.dart';
import 'package:photoquest_app/services/location_service.dart';
import 'package:intl/date_symbol_data_local.dart';

Spot _spot(int id, double lat, double lng) => Spot(
  id: id,
  name: 'Spot $id',
  category: 'landscape',
  description: '-',
  latitude: lat,
  longitude: lng,
  bestTime: 'any',
  photoTypes: const [],
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('Haversine', () {
    test('Titik yang sama -> 0 km', () {
      expect(GeoUtils.haversineKm(-7.78, 110.36, -7.78, 110.36), 0);
    });

    test('1 derajat bujur di khatulistiwa = 2πR/360 ≈ 111,195 km', () {
      expect(GeoUtils.haversineKm(0, 0, 0, 1), closeTo(111.195, 0.001));
    });

    test('Simetris: A->B sama dengan B->A', () {
      final ab = GeoUtils.haversineKm(-7.7829, 110.3671, -7.7520, 110.4915);
      final ba = GeoUtils.haversineKm(-7.7520, 110.4915, -7.7829, 110.3671);
      expect(ab, closeTo(ba, 1e-9));
    });

    test('Tugu Jogja -> Candi Prambanan sekitar 14 km (koordinat seed)', () {
      final d = GeoUtils.haversineKm(-7.7829, 110.3671, -7.7520, 110.4915);
      expect(d, closeTo(14.1, 0.3));
    });
  });

  test('sortByDistance mengurutkan spot dari yang terdekat', () {
    final loc = LocationProvider(LocationService(), DbHelper.instance)
      ..position = const LatLng(-7.7829, 110.3671); // Tugu
    final sorted = loc.sortByDistance([
      _spot(1, -8.0255, 110.3290), // Parangtritis (jauh)
      _spot(2, -7.7926, 110.3658), // Malioboro (dekat)
      _spot(3, -7.7520, 110.4915), // Prambanan (sedang)
    ]);
    expect(sorted.map((s) => s.id), [2, 3, 1]);
  });

  test('Tanpa posisi: distanceTo null dan urutan tidak berubah', () {
    final loc = LocationProvider(LocationService(), DbHelper.instance);
    final spots = [_spot(1, 0, 0), _spot(2, 1, 1)];
    expect(loc.distanceTo(spots.first), isNull);
    expect(loc.sortByDistance(spots), same(spots));
  });

  test('Format jarak: < 1 km dalam meter, selebihnya km 1 desimal', () {
    expect(Formatters.distance(0.85), '850 m');
    expect(Formatters.distance(3.42), '3,4 km');
  });
}
