import 'package:local_auth/local_auth.dart';

/// Hasil percobaan autentikasi biometrik.
class BiometricResult {
  const BiometricResult.success() : success = true, message = null;
  const BiometricResult.failure(this.message) : success = false;

  final bool success;
  final String? message;
}

/// Pembungkus local_auth (sidik jari / wajah).
///
/// Biometrik TIDAK menggantikan password di server. Biometrik hanya "membuka"
/// JWT yang sudah tersimpan terenkripsi di perangkat setelah login password.
class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// true jika perangkat punya sensor biometrik DAN sudah ada sidik jari/wajah terdaftar.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics; // ada hardware biometrik?
      final supported = await _auth.isDeviceSupported(); // OS mendukung?
      if (!canCheck || !supported) return false;
      final enrolled = await _auth.getAvailableBiometrics(); // ada yang terdaftar?
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Menampilkan dialog biometrik sistem Android.
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true, // hanya sidik jari/wajah, bukan PIN
      );
      return ok
          ? const BiometricResult.success()
          : const BiometricResult.failure('Biometrik tidak dikenali');
    } on LocalAuthException catch (e) {
      return BiometricResult.failure(_messageFor(e.code));
    } catch (_) {
      return const BiometricResult.failure('Biometrik gagal dijalankan');
    }
  }

  String _messageFor(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'Login biometrik dibatalkan';
      case LocalAuthExceptionCode.timeout:
        return 'Waktu login biometrik habis';
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return 'Terlalu banyak percobaan. Biometrik dikunci sementara';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Belum ada sidik jari/wajah terdaftar di perangkat';
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'Sensor biometrik tidak tersedia';
      default:
        return 'Biometrik gagal (${code.name})';
    }
  }
}
