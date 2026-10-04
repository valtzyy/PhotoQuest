import '../local/spot_dao.dart';
import '../models/spot.dart';
import '../remote/api_exception.dart';
import '../remote/spot_api.dart';
import 'cached_result.dart';

/// Spot & favorit dengan pola: server -> cache sqflite -> tampil;
/// jika server tidak terjangkau -> tampilkan dari cache (Mode offline).
class SpotRepository {
  SpotRepository(this._api, this._dao);

  final SpotApi _api;
  final SpotDao _dao;

  Future<CachedResult<List<Spot>>> getSpots({
    String? search,
    String? category,
  }) async {
    try {
      final spots = await _api.list(search: search, category: category);
      final unfiltered = (search == null || search.isEmpty) && category == null;
      // Daftar lengkap -> ganti seluruh cache; hasil filter -> perbarui sebagian.
      unfiltered ? await _dao.replaceAll(spots) : await _dao.upsert(spots);
      return CachedResult(spots);
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      // Offline: jalankan pencarian & filter yang sama di database lokal.
      if (await _dao.count() == 0) rethrow; // belum pernah online sama sekali
      final spots = await _dao.query(search: search, category: category);
      return CachedResult(
        spots,
        fromCache: true,
        cachedAt: await _dao.lastCachedAt(),
      );
    }
  }

  Future<CachedResult<Spot>> getSpot(int id) async {
    try {
      final spot = await _api.detail(id);
      await _dao.upsert([spot]);
      return CachedResult(spot);
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      final cached = await _dao.byId(id);
      if (cached == null) rethrow;
      return CachedResult(cached, fromCache: true);
    }
  }

  Future<CachedResult<Set<int>>> favoriteIds() async {
    try {
      final ids = await _api.favoriteIds();
      await _dao.replaceFavorites(ids);
      return CachedResult(ids);
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      return CachedResult(await _dao.favoriteIds(), fromCache: true);
    }
  }

  /// Tambah/hapus favorit hanya saat online (tanpa antrean offline).
  Future<void> setFavorite(int spotId, bool favorite) async {
    try {
      favorite
          ? await _api.addFavorite(spotId)
          : await _api.removeFavorite(spotId);
      await _dao.setFavorite(spotId, favorite);
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        throw const ApiException(
          'Sedang offline. Favorit hanya bisa diubah saat online.',
          isNetworkError: true,
        );
      }
      rethrow;
    }
  }
}
