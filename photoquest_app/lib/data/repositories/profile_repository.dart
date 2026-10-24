import 'dart:convert';
import 'dart:typed_data';

import '../local/json_cache.dart';
import '../models/challenge_attempt.dart';
import '../models/user.dart';
import '../remote/api_exception.dart';
import '../remote/challenge_api.dart';
import '../remote/user_api.dart';
import 'cached_result.dart';

/// Data halaman Profil: ubah nama, foto profil, riwayat challenge.
class ProfileRepository {
  ProfileRepository(this._userApi, this._challengeApi, this._cache);

  final UserApi _userApi;
  final ChallengeApi _challengeApi;
  final JsonCache _cache;
  static const _historyCache = 'challenge_history';
  static const _photoCache = 'profile_photo';

  Future<User> updateName(String name) => _userApi.updateName(name.trim());

  Future<User> uploadPhoto(String filePath) => _userApi.uploadPhoto(filePath);

  /// Foto profil dengan cache di HP (prefix cache_user_, terhapus saat logout):
  /// online -> unduh lalu simpan; offline -> foto terakhir yang tersimpan.
  Future<CachedResult<Uint8List>> photo(String photoUrl) async {
    try {
      final bytes = await _userApi.fetchPhoto(photoUrl);
      await _cache.save(_photoCache, {
        'url': photoUrl,
        'b64': base64Encode(bytes),
      });
      return CachedResult(bytes);
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      final cached = await _cache.read(_photoCache);
      if (cached == null) rethrow;
      final data = cached.data as Map<String, dynamic>;
      return CachedResult(
        base64Decode(data['b64'] as String),
        fromCache: true,
        cachedAt: cached.savedAt,
      );
    }
  }

  /// Riwayat challenge dengan fallback cache saat offline.
  Future<CachedResult<List<ChallengeAttempt>>> challengeHistory() async {
    try {
      final raw = await _challengeApi.historyRaw();
      await _cache.save(_historyCache, raw);
      return CachedResult(_parse(raw));
    } on ApiException catch (e) {
      if (!e.isNetworkError) rethrow;
      final cached = await _cache.read(_historyCache);
      if (cached == null) rethrow;
      return CachedResult(
        _parse(cached.data as List<dynamic>),
        fromCache: true,
        cachedAt: cached.savedAt,
      );
    }
  }

  List<ChallengeAttempt> _parse(List<dynamic> raw) => raw
      .map((e) => ChallengeAttempt.fromJson(e as Map<String, dynamic>))
      .toList();
}
