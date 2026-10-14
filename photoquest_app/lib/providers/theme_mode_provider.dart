import 'package:flutter/material.dart';

/// Pilihan tema tampilan (Sistem / Terang / Gelap) dari halaman Profil.
///
/// Penyimpanan diinjeksi sebagai fungsi baca/tulis (di aplikasi: tabel
/// settings sqflite) agar mudah dites tanpa database.
class ThemeModeProvider extends ChangeNotifier {
  ThemeModeProvider({required this._read, required this._write});

  static const settingKey = 'theme_mode';

  final Future<String?> Function() _read;
  final Future<void> Function(String value) _write;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Muat pilihan tersimpan; nilai kosong/tak dikenal = ikuti sistem.
  Future<void> load() async {
    final saved = await _read();
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _write(mode.name);
  }
}
