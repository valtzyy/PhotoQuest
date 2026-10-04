import '../local/weather_dao.dart';
import '../models/weather_info.dart';
import '../remote/api_exception.dart';
import '../remote/weather_api.dart';
import 'cached_result.dart';

/// Cuaca dengan fallback berlapis:
///   1. Server (live / cache server / estimasi server)
///   2. Server tak terjangkau -> cache sqflite `last_weather`
///   3. Tidak ada cache       -> estimasi lokal 05:30 / 17:45 WIB
class WeatherRepository {
  WeatherRepository(this._api, this._dao, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final WeatherApi _api;
  final WeatherDao _dao;
  final DateTime Function() _now;

  /// Kunci cache: koordinat dibulatkan 2 desimal (~1 km), sama dengan backend.
  static String keyFor(double lat, double lng) =>
      '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';

  Future<CachedResult<WeatherInfo>> get(double lat, double lng) async {
    final key = keyFor(lat, lng);
    try {
      final raw = await _api.raw(lat, lng);
      final info = WeatherInfo.fromJson(raw);
      if (info.isEstimate) {
        // Open-Meteo gagal di server: data asli lama di HP lebih baik daripada estimasi.
        final cached = await _readCache(key);
        if (cached != null) return cached;
        return CachedResult(info);
      }
      await _dao.save(key, raw);
      return CachedResult(info);
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      return await _readCache(key) ??
          CachedResult(WeatherInfo.estimate(_now()), fromCache: true);
    }
  }

  Future<CachedResult<WeatherInfo>?> _readCache(String key) async {
    final cached = await _dao.read(key);
    if (cached == null) return null;
    return CachedResult(
      WeatherInfo.fromJson(cached.json),
      fromCache: true,
      cachedAt: cached.fetchedAt,
    );
  }
}
