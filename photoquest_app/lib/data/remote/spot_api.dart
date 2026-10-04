import '../models/spot.dart';
import 'api_client.dart';

/// Endpoint spot dan favorit.
class SpotApi {
  SpotApi(this._client);
  final ApiClient _client;

  /// GET /spots?search=&category= (pencarian & filter dilakukan di server).
  Future<List<Spot>> list({String? search, String? category}) async {
    final data = await _client.send<List<dynamic>>(
      (dio) => dio.get(
        '/spots',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'category': ?category, // dikirim hanya jika tidak null
        },
      ),
    );
    return data.map((e) => Spot.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Spot> detail(int id) async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.get('/spots/$id'),
    );
    return Spot.fromJson(data);
  }

  /// GET /favorites -> cukup ambil ID-nya (data spot lengkap sudah ada di cache).
  Future<Set<int>> favoriteIds() async {
    final data = await _client.send<List<dynamic>>(
      (dio) => dio.get('/favorites'),
    );
    return data.map((e) => (e as Map<String, dynamic>)['id'] as int).toSet();
  }

  Future<void> addFavorite(int spotId) => _client.send<dynamic>(
    (dio) => dio.post('/favorites', data: {'spot_id': spotId}),
  );

  Future<void> removeFavorite(int spotId) =>
      _client.send<dynamic>((dio) => dio.delete('/favorites/$spotId'));
}
