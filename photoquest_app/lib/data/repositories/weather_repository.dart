import '../local/weather_dao.dart';
import '../models/weather_info.dart';
import '../remote/api_exception.dart';
import '../remote/open_meteo_api.dart';
import '../remote/weather_api.dart';
import 'cached_result.dart';

/// Cuaca dengan fallback berlapis:
///   1. Server (live / cache server)
///   2. Server gagal atau hanya memberi estimasi (mis. Open-Meteo 429 di IP server)
///      -> HP memanggil Open-Meteo langsung (IP HP sendiri)
///   3. Open-Meteo juga gagal -> cache sqflite `last_weather`
///   4. Tidak ada cache -> estimasi dari server, atau estimasi lokal 05:30 / 17:45 WIB
///
/// `CachedResult.fromCache` = true hanya bila server tidak terjangkau (benar-benar
/// offline). Cache HP yang dipakai saat server terjangkau ditandai lewat `cachedAt`.
class WeatherRepository {
  WeatherRepository(
    this._api,
    this._dao, {
    this._direct,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final WeatherApi _api;
  final WeatherDao _dao;
  final OpenMeteoApi? _direct;
  final DateTime Function() _now;

  /// Kunci cache: koordinat dibulatkan 2 desimal (~1 km), sama dengan backend.
  static String keyFor(double lat, double lng) =>
      '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';

  Future<CachedResult<WeatherInfo>> get(double lat, double lng) async {
    final key = keyFor(lat, lng);

    WeatherInfo? serverEstimate; // server terjangkau tapi tanpa data cuaca
    var serverReachable = true;
    try {
      final raw = await _api.raw(lat, lng);
      final info = WeatherInfo.fromJson(raw);
      if (!info.isEstimate) {
        await _dao.save(key, raw);
        return CachedResult(info);
      }
      serverEstimate = info;
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      serverReachable = false;
    }

    final live = await _fetchDirect(key, lat, lng);
    if (live != null) return CachedResult(live);

    // Data asli lama di HP lebih baik daripada estimasi.
    final cached = await _readCache(key);
    if (cached != null) {
      return serverReachable
          ? CachedResult(cached.data, cachedAt: cached.cachedAt)
          : cached;
    }
    return serverEstimate != null
        ? CachedResult(serverEstimate)
        : CachedResult(WeatherInfo.estimate(_now()), fromCache: true);
  }

  /// Ambil langsung dari Open-Meteo; null bila tidak tersedia atau gagal.
  Future<WeatherInfo?> _fetchDirect(String key, double lat, double lng) async {
    final direct = _direct;
    if (direct == null) return null;
    try {
      final json = openMeteoToWeatherJson(await direct.fetch(lat, lng), _now());
      final info = WeatherInfo.fromJson(json);
      await _dao.save(key, json);
      return info;
    } catch (_) {
      return null;
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
