import '../local/json_cache.dart';
import '../models/feedback_item.dart';
import '../remote/api_exception.dart';
import '../remote/feedback_api.dart';
import 'cached_result.dart';

/// Saran & Kesan: online = ambil dari server lalu simpan ke cache;
/// offline = tampilkan cache terakhir. Kirim hanya bisa saat online.
class FeedbackRepository {
  FeedbackRepository(this._api, this._cache);

  final FeedbackApi _api;
  final JsonCache _cache;
  static const _cacheName = 'feedback_me';

  Future<CachedResult<List<FeedbackItem>>> getMine() async {
    try {
      final raw = await _api.mineRaw();
      await _cache.save(_cacheName, raw); // 1. server -> 2. cache lokal
      return CachedResult(_parse(raw)); // 3. tampilkan
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      final cached = await _cache.read(_cacheName);
      if (cached == null) rethrow; // offline dan belum ada cache
      return CachedResult(
        _parse(cached.data as List<dynamic>),
        fromCache: true,
        cachedAt: cached.savedAt,
      );
    }
  }

  Future<FeedbackItem> send(String saran, String kesan) async {
    try {
      return await _api.send(saran.trim(), kesan.trim());
    } on ApiException catch (e) {
      // Tidak ada antrean offline: beri tahu user untuk mencoba lagi saat online.
      if (e.isNetworkError) {
        throw const ApiException(
          'Sedang offline. Saran & kesan hanya bisa dikirim saat online.',
          isNetworkError: true,
        );
      }
      rethrow;
    }
  }

  List<FeedbackItem> _parse(List<dynamic> raw) =>
      raw.map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>)).toList();
}
