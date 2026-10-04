import 'package:flutter/material.dart';

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

/// Label bahasa Indonesia untuk nilai enum dari backend.
class Labels {
  Labels._();

  static const _category = {
    'landscape': 'Lanskap',
    'architecture': 'Arsitektur',
    'street': 'Jalanan',
    'nature': 'Alam',
    'culture': 'Budaya',
  };

  static const _categoryIcon = {
    'landscape': Icons.landscape,
    'architecture': Icons.account_balance,
    'street': Icons.storefront,
    'nature': Icons.forest,
    'culture': Icons.temple_hindu,
  };

  static const _bestTime = {
    'sunrise': 'Matahari terbit',
    'sunset': 'Matahari terbenam',
    'any': 'Kapan saja',
  };

  static const _photoType = {
    'landscape': 'Lanskap',
    'sunset': 'Sunset',
    'street': 'Street',
    'architecture': 'Arsitektur',
    'portrait': 'Potret',
  };

  static String category(String v) => _category[v] ?? v;
  static IconData categoryIcon(String v) => _categoryIcon[v] ?? Icons.place;
  static String bestTime(String v) => _bestTime[v] ?? v;
  static String photoType(String v) => _photoType[v] ?? v;
}
