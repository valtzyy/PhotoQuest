import '../local/json_cache.dart';
import '../models/currency.dart';
import '../remote/api_exception.dart';
import '../remote/converter_api.dart';
import 'cached_result.dart';

/// Kurs & gear: server -> cache sqflite -> tampil; offline -> cache;
/// kurs tanpa cache -> kurs tetap (fallback) agar konverter tetap bisa dipakai.
class ConverterRepository {
  ConverterRepository(this._api, this._cache, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ConverterApi _api;

  /// Cache dengan prefix `cache_app_` (bukan data user, tidak dihapus saat logout).
  final JsonCache _cache;
  final DateTime Function() _now;

  Future<CachedResult<CurrencyRates>> rates() async {
    try {
      final raw = await _api.ratesRaw();
      await _cache.save('currency', raw);
      return CachedResult(CurrencyRates.fromJson(raw));
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      final cached = await _cache.read('currency');
      if (cached != null) {
        return CachedResult(
          CurrencyRates.fromJson(cached.data as Map<String, dynamic>),
          fromCache: true,
          cachedAt: cached.savedAt,
        );
      }
      return CachedResult(CurrencyRates.fallback(_now()), fromCache: true);
    }
  }

  Future<CachedResult<List<GearItem>>> gear() async {
    List<GearItem> parse(List<dynamic> raw) =>
        raw.map((e) => GearItem.fromJson(e as Map<String, dynamic>)).toList();
    try {
      final raw = await _api.gearRaw();
      await _cache.save('gear', raw);
      return CachedResult(parse(raw));
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      final cached = await _cache.read('gear');
      if (cached == null) rethrow;
      return CachedResult(
        parse(cached.data as List<dynamic>),
        fromCache: true,
        cachedAt: cached.savedAt,
      );
    }
  }
}
