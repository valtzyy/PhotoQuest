/// Konfigurasi aplikasi.
///
/// Base URL backend TIDAK ditulis langsung di kode, tetapi dikirim saat build/run:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
/// HP fisik tidak bisa memakai "localhost" (itu menunjuk ke HP itu sendiri),
/// jadi gunakan IP LAN laptop yang menjalankan backend.
///
/// Catatan: aplikasi TIDAK menyimpan API key apa pun. Semua key ada di backend (.env).
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Default untuk emulator Android (10.0.2.2 = localhost milik laptop).
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Timeout semua request jaringan (requirement: 8 detik + fallback).
  static const Duration requestTimeout = Duration(seconds: 8);
}
