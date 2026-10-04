/// Validasi form (aturan sama dengan validasi di backend).
class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email wajib diisi';
    if (!_emailRegex.hasMatch(v)) return 'Format email tidak valid';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? name(String? value) {
    if ((value?.trim().length ?? 0) < 2) return 'Nama minimal 2 karakter';
    return null;
  }
}
