import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Database lokal (SQLite via sqflite).
///
/// Server tetap sumber kebenaran. Database lokal hanya:
/// - cache data server agar aplikasi tetap bisa dipakai offline, dan
/// - data yang memang lokal (soal PhotoQuiz, pengaturan).
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  static const _dbName = 'photoquest.db';
  static const _dbVersion = 1;

  Database? _db;

  /// Membuka database sekali (lazy), lalu dipakai ulang.
  Future<Database> get database async {
    return _db ??= await openDatabase(
      join(await getDatabasesPath(), _dbName),
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Salinan tabel `spots` dari server (mode offline). photo_types disimpan sebagai JSON.
    await db.execute('''
      CREATE TABLE spots_cache (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        best_time TEXT NOT NULL,
        photo_types TEXT NOT NULL,
        tips TEXT,
        image_url TEXT,
        entry_fee_idr INTEGER,
        cached_at TEXT NOT NULL
      )''');

    // ID spot favorit milik user yang sedang login.
    await db.execute(
      'CREATE TABLE favorites_cache (spot_id INTEGER PRIMARY KEY)',
    );

    // Soal PhotoQuiz (seed lokal, bisa dimainkan offline). options = JSON array.
    await db.execute('''
      CREATE TABLE quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        options TEXT NOT NULL,
        answer_index INTEGER NOT NULL,
        explanation TEXT
      )''');

    // Respons cuaca terakhir per lokasi/spot (json mentah + waktu ambil).
    await db.execute('''
      CREATE TABLE last_weather (
        cache_key TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )''');

    // Key-value umum: last_lat, last_lng, cache JSON kecil, dll.
    await db.execute(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)',
    );
  }

  // ------------------------------------------------------------- settings
  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Dipanggil saat logout: hapus cache yang terkait user,
  /// tetapi pertahankan data umum (spot, soal quiz, cuaca).
  Future<void> clearUserData() async {
    final db = await database;
    await db.delete('favorites_cache');
    await db.delete('settings', where: "key LIKE 'cache_user_%'");
  }
}
