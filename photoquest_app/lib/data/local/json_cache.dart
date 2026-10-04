import 'dart:convert';

import 'db_helper.dart';

/// Cache JSON kecil di tabel `settings` (mis. riwayat feedback, riwayat challenge).
/// Key diawali `cache_user_` agar otomatis terhapus saat logout.
class JsonCache {
  JsonCache(this._db);
  final DbHelper _db;

  Future<void> save(String name, Object? json) async {
    final payload = jsonEncode({
      'saved_at': DateTime.now().toIso8601String(),
      'data': json,
    });
    await _db.setSetting('cache_user_$name', payload);
  }

  /// Mengembalikan (data, waktu simpan) atau null jika belum pernah disimpan.
  Future<({Object? data, DateTime savedAt})?> read(String name) async {
    final raw = await _db.getSetting('cache_user_$name');
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (
      data: map['data'],
      savedAt: DateTime.parse(map['saved_at'] as String),
    );
  }
}
