import 'package:intl/intl.dart';

/// Format tampilan tanggal/angka berbahasa Indonesia.
/// Locale 'id_ID' diinisialisasi di main.dart (initializeDateFormatting).
class Formatters {
  Formatters._();

  /// Contoh: 4 Okt 2026, 17.45 (waktu lokal HP)
  static String dateTime(DateTime value) =>
      DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(value.toLocal());

  /// Contoh: 1,25
  static String decimal(num value, {int digits = 2}) =>
      NumberFormat.decimalPatternDigits(
        locale: 'id_ID',
        decimalDigits: digits,
      ).format(value);
}
