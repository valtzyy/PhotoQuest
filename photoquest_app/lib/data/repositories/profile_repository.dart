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

  Future<User> updateName(String name) => _userApi.updateName(name.trim());

  Future<User> uploadPhoto(String filePath) => _userApi.uploadPhoto(filePath);

  Future<Uint8List> fetchPhoto(String photoUrl) =>
      _userApi.fetchPhoto(photoUrl);

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
