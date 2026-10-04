import 'package:flutter/foundation.dart';

import '../data/models/user.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/auth_repository.dart';
import '../services/biometric_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// State autentikasi aplikasi: user aktif, status login, mode offline, biometrik.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo, this._biometric, ApiClient client) {
    // Interceptor dio memanggil ini setiap kali server membalas 401.
    client.onUnauthorized = _handleUnauthorized;
  }

  final AuthRepository _repo;
  final BiometricService _biometric;

  AuthStatus status = AuthStatus.unknown;
  User? user;

  /// true jika session dipulihkan dari cache karena server tidak terjangkau.
  bool isOffline = false;

  bool biometricEnabled = false;

  /// Dipanggil saat session kedaluwarsa (diisi di main.dart untuk navigasi ke Login).
  void Function(String message)? onSessionExpired;
  bool _expiring = false;

  // ------------------------------------------------------------------ session
  Future<bool> hasToken() => _repo.hasToken();

  Future<RestoreResult> restoreSession() async {
    final result = await _repo.restoreSession();
    if (result.status == RestoreStatus.online || result.status == RestoreStatus.offline) {
      _setLoggedIn(result.user!, offline: result.status == RestoreStatus.offline);
    }
    return result;
  }

  Future<void> login(String email, String password) async {
    final u = await _repo.login(email.trim(), password);
    _setLoggedIn(u);
  }

  Future<void> register(String name, String email, String password) async {
    final u = await _repo.register(name.trim(), email.trim(), password);
    _setLoggedIn(u);
  }

  Future<void> logout() async {
    await _repo.logout();
    user = null;
    isOffline = false;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setLoggedIn(User u, {bool offline = false}) {
    user = u;
    isOffline = offline;
    status = AuthStatus.authenticated;
    _expiring = false;
    notifyListeners();
  }

  /// Logout otomatis karena token ditolak server (kedaluwarsa / tidak valid).
  /// Dijaga agar hanya berjalan sekali walau beberapa request gagal bersamaan.
  Future<void> _handleUnauthorized() async {
    if (_expiring) return;
    _expiring = true;
    await logout();
    onSessionExpired?.call('Sesi berakhir. Silakan login kembali.');
  }

  // ---------------------------------------------------------------- biometrik
  Future<void> loadBiometricSetting() async {
    biometricEnabled = await _repo.isBiometricEnabled();
    notifyListeners();
  }

  Future<bool> isBiometricAvailable() => _biometric.isAvailable();

  Future<BiometricResult> authenticateBiometric() =>
      _biometric.authenticate('Verifikasi untuk membuka PhotoQuest');

  /// Tawarkan aktivasi biometrik hanya sekali (setelah login password pertama).
  Future<bool> shouldOfferBiometric() async {
    if (await _repo.isBiometricEnabled()) return false;
    if (await _repo.wasBiometricAsked()) return false;
    return _biometric.isAvailable();
  }

  Future<void> markBiometricAsked() => _repo.setBiometricAsked();

  /// Mengaktifkan/menonaktifkan login biometrik.
  /// Saat mengaktifkan, user harus lolos verifikasi biometrik dulu.
  /// Mengembalikan pesan error, atau null jika berhasil.
  Future<String?> setBiometricEnabled(bool enable) async {
    if (enable) {
      if (!await _biometric.isAvailable()) {
        return 'Perangkat tidak mendukung biometrik atau belum ada yang terdaftar';
      }
      final result = await _biometric.authenticate('Konfirmasi untuk mengaktifkan login biometrik');
      if (!result.success) return result.message;
    }
    await _repo.setBiometricEnabled(enable);
    biometricEnabled = enable;
    notifyListeners();
    return null;
  }
}
