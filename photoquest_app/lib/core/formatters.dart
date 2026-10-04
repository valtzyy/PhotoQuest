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

  /// Contoh: Rp15.000
  static String rupiah(num value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  ).format(value);

  /// Contoh: 850 m, 3,4 km
  static String distance(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${decimal(km, digits: 1)} km';
}
