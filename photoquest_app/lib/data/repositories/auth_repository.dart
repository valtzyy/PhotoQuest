import '../local/db_helper.dart';
import '../local/secure_store.dart';
import '../models/user.dart';
import '../remote/api_exception.dart';
import '../remote/auth_api.dart';

/// Hasil pemulihan session saat aplikasi dibuka.
enum RestoreStatus {
  /// Token valid, data user terbaru dari server.
  online,

  /// Server tidak bisa dihubungi, memakai user dari cache (Mode offline).
  offline,

  /// Token ditolak server (401) -> token sudah dihapus.
  unauthorized,

  /// Server tidak bisa dihubungi dan tidak ada cache user.
  failed,
}

class RestoreResult {
  const RestoreResult(this.status, {this.user, this.message});
  final RestoreStatus status;
  final User? user;
  final String? message;
}

/// Menggabungkan API auth (remote) dan secure storage (lokal).
class AuthRepository {
  AuthRepository(this._api, this._store, this._db);

  final AuthApi _api;
  final SecureStore _store;
  final DbHelper _db;

  Future<User> login(String email, String password) async {
    final result = await _api.login(email, password);
    await _saveSession(result);
    return result.user;
  }

  Future<User> register(String name, String email, String password) async {
    final result = await _api.register(name, email, password);
    await _saveSession(result);
    return result.user;
  }

  Future<void> _saveSession(AuthResult result) async {
    await _store.saveToken(result.token);
    await _store.saveUser(result.user);
  }

  Future<bool> hasToken() async => await _store.readToken() != null;

  /// Memulihkan session: validasi token ke /auth/me.
  Future<RestoreResult> restoreSession() async {
    try {
      final user = await _api.me();
      await _store.saveUser(user);
      return RestoreResult(RestoreStatus.online, user: user);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _store.clearSession();
        return RestoreResult(RestoreStatus.unauthorized, message: e.message);
      }
      // Gagal jaringan: pakai user terakhir agar app tetap bisa dipakai offline.
      final cached = await _store.readUser();
      if (cached != null) {
        return RestoreResult(
          RestoreStatus.offline,
          user: cached,
          message: e.message,
        );
      }
      return RestoreResult(RestoreStatus.failed, message: e.message);
    }
  }

  /// Logout: hapus token + user (secure storage) dan cache milik user (sqflite).
  Future<void> logout() async {
    await _store.clearSession();
    await _db.clearUserData();
  }

  /// Simpan user terbaru (mis. setelah ubah nama/foto) agar cache offline ikut ter-update.
  Future<void> saveUser(User user) => _store.saveUser(user);

  Future<bool> isBiometricEnabled() => _store.isBiometricEnabled();
  Future<void> setBiometricEnabled(bool value) =>
      _store.setBiometricEnabled(value);
  Future<bool> wasBiometricAsked() => _store.wasBiometricAsked();
  Future<void> setBiometricAsked() => _store.setBiometricAsked();
}
