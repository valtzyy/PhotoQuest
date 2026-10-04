import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';

/// Cache respons cuaca terakhir per lokasi/spot (tabel `last_weather`).
class WeatherDao {
  WeatherDao(this._helper);
  final DbHelper _helper;

  Future<void> save(String key, Map<String, dynamic> json) async {
    final db = await _helper.database;
    await db.insert('last_weather', {
      'cache_key': key,
      'json': jsonEncode(json),
      'fetched_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<({Map<String, dynamic> json, DateTime fetchedAt})?> read(
    String key,
  ) async {
    final db = await _helper.database;
    final rows = await db.query(
      'last_weather',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (
      json: jsonDecode(rows.first['json'] as String) as Map<String, dynamic>,
      fetchedAt: DateTime.parse(rows.first['fetched_at'] as String),
    );
  }
}
