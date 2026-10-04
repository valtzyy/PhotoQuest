/// Konstanta yang dipakai di banyak tempat.
class AppConstants {
  AppConstants._();

  static const String appName = 'PhotoQuest';

  /// Kategori spot (sama dengan CHECK constraint di tabel `spots` backend).
  static const List<String> spotCategories = [
    'landscape',
    'architecture',
    'street',
    'nature',
    'culture',
  ];

  /// Lokasi demo default: Tugu Jogja (dipakai jika GPS gagal/ditolak).
  /// TO_VERIFY: cek ulang di OpenStreetMap / Google Maps.
  static const double demoLat = -7.7829;
  static const double demoLng = 110.3671;
}
