import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

/// Penyimpanan terenkripsi untuk data sensitif session.
///
/// Di Android, flutter_secure_storage mengenkripsi nilai dengan AES-GCM, dan
/// kunci AES-nya dilindungi Android Keystore (tidak bisa dibaca aplikasi lain).
/// Yang disimpan: JWT, data user terakhir, dan preferensi biometrik.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kToken = 'auth_token';
  static const _kUser = 'cached_user';
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kBiometricAsked = 'biometric_asked';

  // ---- Token JWT ----
  Future<void> saveToken(String token) => _storage.write(key: _kToken, value: token);
  Future<String?> readToken() => _storage.read(key: _kToken);

  // ---- User terakhir (dipakai saat offline agar app tetap bisa dibuka) ----
  Future<void> saveUser(User user) =>
      _storage.write(key: _kUser, value: jsonEncode(user.toJson()));

  Future<User?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null) return null;
    return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // ---- Preferensi biometrik (milik perangkat, tidak dihapus saat logout) ----
  Future<bool> isBiometricEnabled() async =>
      await _storage.read(key: _kBiometricEnabled) == 'true';

  Future<void> setBiometricEnabled(bool value) =>
      _storage.write(key: _kBiometricEnabled, value: value.toString());

  /// Apakah dialog "Aktifkan login biometrik?" sudah pernah ditampilkan.
  Future<bool> wasBiometricAsked() async =>
      await _storage.read(key: _kBiometricAsked) == 'true';

  Future<void> setBiometricAsked() =>
      _storage.write(key: _kBiometricAsked, value: 'true');

  /// Logout: hapus token dan cache user.
  Future<void> clearSession() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUser);
  }
}
