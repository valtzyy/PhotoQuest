/// Hasil membaca angka yang diketik pengguna: [value] atau [error], salah satunya.
class ParsedAmount {
  const ParsedAmount.ok(this.value) : error = null;
  const ParsedAmount.fail(this.error) : value = null;

  final double? value;
  final String? error;
}

/// Membaca angka dari kolom input Kurs.
///
/// Aturan (kebiasaan Indonesia):
/// - Titik/koma yang diikuti TEPAT 3 digit adalah pemisah ribuan: "1.000" = 1000,
///   "1.000.000" = 1000000. Selain itu dianggap desimal: "83,5", "83.5", "0.123".
/// - Jika ada titik DAN koma, pemisah terakhir adalah desimal: "1.234,56" = "1,234.56".
/// - Dibatasi < 1 triliun. Di atasnya, `double` kehilangan presisi (±9×10¹⁵) dan
///   pemformat uang overflow di 9.223.372.036.854.775.807, jadi ditolak dengan pesan.
class AmountParser {
  AmountParser._();

  static const _invalid = 'Format angka tidak valid';
  static const _tooBig = 'Maksimal 999.999.999.999';
  static const _limit = 1e12;

  static ParsedAmount parse(String input) {
    final t = input.trim();
    if (t.isEmpty) return const ParsedAmount.ok(0);
    if (!RegExp(r'^[0-9.,]+$').hasMatch(t)) {
      return const ParsedAmount.fail(_invalid);
    }
    final normalized = _normalize(t);
    if (normalized == null) return const ParsedAmount.fail(_invalid);
    final value = double.parse(normalized);
    if (value >= _limit) return const ParsedAmount.fail(_tooBig);
    return ParsedAmount.ok(value);
  }

  /// Ubah ke bentuk "1234.56" (titik desimal, tanpa pemisah ribuan); null jika tidak valid.
  static String? _normalize(String t) {
    final hasDot = t.contains('.');
    final hasComma = t.contains(',');

    if (hasDot && hasComma) {
      final decimalSep = t.lastIndexOf('.') > t.lastIndexOf(',') ? '.' : ',';
      final thousandSep = decimalSep == '.' ? ',' : '.';
      final cut = t.lastIndexOf(decimalSep);
      final whole = t.substring(0, cut);
      final fraction = t.substring(cut + 1);
      if (!_grouped(whole, thousandSep)) return null;
      return '${whole.replaceAll(thousandSep, '')}.${fraction.isEmpty ? '0' : fraction}';
    }

    final sep = hasDot ? '.' : (hasComma ? ',' : null);
    if (sep == null) return t;

    if (t.split(sep).length - 1 > 1) {
      return _grouped(t, sep) ? t.replaceAll(sep, '') : null;
    }
    final cut = t.indexOf(sep);
    final before = t.substring(0, cut);
    final after = t.substring(cut + 1);
    // Hanya pemisah, tanpa angka.
    if (before.isEmpty && after.isEmpty) return null;
    final isThousands =
        after.length == 3 &&
        before.isNotEmpty &&
        before.length <= 3 &&
        int.parse(before) != 0;
    if (isThousands) return '$before$after';
    return '${before.isEmpty ? '0' : before}.${after.isEmpty ? '0' : after}';
  }

  /// "1.000.000" valid bila dipisah [sep]: grup pertama 1–3 digit, sisanya tepat 3 digit.
  static bool _grouped(String s, String sep) =>
      RegExp('^\\d{1,3}(${RegExp.escape(sep)}\\d{3})+\$').hasMatch(s);
}
