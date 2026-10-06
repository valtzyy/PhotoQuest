import 'dart:convert';

import 'db_helper.dart';

/// Cache JSON kecil di tabel `settings`.
///
/// - Prefix default `cache_user_` (mis. riwayat feedback/challenge): data milik user,
///   otomatis terhapus saat logout (lihat DbHelper.clearUserData).
/// - Prefix `cache_app_` (mis. kurs, daftar gear): data umum, tetap disimpan.
class JsonCache {
  JsonCache(this._db, {this.prefix = 'cache_user_'});

  final DbHelper _db;
  final String prefix;

  Future<void> save(String name, Object? json) async {
    final payload = jsonEncode({
      'saved_at': DateTime.now().toIso8601String(),
      'data': json,
    });
    await _db.setSetting('$prefix$name', payload);
  }

  /// Mengembalikan (data, waktu simpan) atau null jika belum pernah disimpan.
  Future<({Object? data, DateTime savedAt})?> read(String name) async {
    final raw = await _db.getSetting('$prefix$name');
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (
      data: map['data'],
      savedAt: DateTime.parse(map['saved_at'] as String),
    );
  }
}
