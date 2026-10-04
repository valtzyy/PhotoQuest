import 'package:sqflite/sqflite.dart';

import '../models/spot.dart';
import 'db_helper.dart';

/// Akses tabel lokal `spots_cache` dan `favorites_cache`.
class SpotDao {
  SpotDao(this._helper);
  final DbHelper _helper;

  /// Ganti seluruh cache (dipakai setelah mengambil daftar lengkap tanpa filter),
  /// sehingga spot yang sudah dihapus di server ikut hilang dari cache.
  Future<void> replaceAll(List<Spot> spots) async {
    final db = await _helper.database;
    final now = DateTime.now();
    await db.transaction((txn) async {
      await txn.delete('spots_cache');
      final batch = txn.batch();
      for (final s in spots) {
        batch.insert('spots_cache', s.toDb(now));
      }
      await batch.commit(noResult: true);
    });
  }

  /// Tambah/perbarui sebagian spot (dipakai untuk hasil pencarian/detail).
  Future<void> upsert(List<Spot> spots) async {
    final db = await _helper.database;
    final now = DateTime.now();
    final batch = db.batch();
    for (final s in spots) {
      batch.insert(
        'spots_cache',
        s.toDb(now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Pencarian offline: logika sama dengan backend (nama/deskripsi + kategori).
  /// LIKE di SQLite tidak peka huruf besar/kecil untuk huruf latin.
  Future<List<Spot>> query({String? search, String? category}) async {
    final db = await _helper.database;
    final where = <String>[];
    final args = <Object>[];
    if (search != null && search.isNotEmpty) {
      final pattern =
          '%${search.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
      where.add(r"(name LIKE ? ESCAPE '\' OR description LIKE ? ESCAPE '\')");
      args.addAll([pattern, pattern]);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    final rows = await db.query(
      'spots_cache',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'name',
    );
    return rows.map(Spot.fromDb).toList();
  }

  Future<Spot?> byId(int id) async {
    final db = await _helper.database;
    final rows = await db.query(
      'spots_cache',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Spot.fromDb(rows.first);
  }

  Future<int> count() async {
    final db = await _helper.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM spots_cache'),
        ) ??
        0;
  }

  /// Waktu cache terakhir diperbarui (untuk teks banner offline).
  Future<DateTime?> lastCachedAt() async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT MAX(cached_at) AS t FROM spots_cache',
    );
    final t = rows.first['t'] as String?;
    return t == null ? null : DateTime.parse(t);
  }

  // ------------------------------------------------------------- favorit
  Future<Set<int>> favoriteIds() async {
    final db = await _helper.database;
    final rows = await db.query('favorites_cache');
    return rows.map((r) => r['spot_id'] as int).toSet();
  }

  Future<void> replaceFavorites(Set<int> ids) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      await txn.delete('favorites_cache');
      for (final id in ids) {
        await txn.insert('favorites_cache', {'spot_id': id});
      }
    });
  }

  Future<void> setFavorite(int spotId, bool favorite) async {
    final db = await _helper.database;
    if (favorite) {
      await db.insert('favorites_cache', {
        'spot_id': spotId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'favorites_cache',
        where: 'spot_id = ?',
        whereArgs: [spotId],
      );
    }
  }
}
