/// Mata uang yang didukung konverter.
const supportedCurrencies = ['IDR', 'USD', 'EUR', 'JPY'];

/// Kurs relatif terhadap IDR: rates['USD'] = berapa USD untuk 1 rupiah.
class CurrencyRates {
  const CurrencyRates({
    required this.base,
    required this.date,
    required this.source,
    required this.fetchedAt,
    required this.rates,
  });

  final String base;

  /// Tanggal kurs referensi ECB (yyyy-MM-dd).
  final String date;

  /// live | cache | fallback
  final String source;
  final DateTime fetchedAt;
  final Map<String, double> rates;

  bool get isFallback => source == 'fallback';

  /// Konversi: amount (mata uang [from]) -> IDR -> mata uang [to].
  ///   IDR = amount / rates[from];  hasil = IDR × rates[to]
  double convert(double amount, String from, String to) =>
      amount / rates[from]! * rates[to]!;

  factory CurrencyRates.fromJson(Map<String, dynamic> json) => CurrencyRates(
    base: json['base'] as String,
    date: json['date'] as String,
    source: json['source'] as String,
    fetchedAt: DateTime.parse(json['fetched_at'] as String),
    rates: (json['rates'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
  );

  /// Kurs tetap jika server & cache tidak tersedia (snapshot Frankfurter 2 Okt 2026,
  /// sama dengan fallback di backend). Dihitung sebagai kurs silang dari base EUR.
  factory CurrencyRates.fallback(DateTime now) {
    const eur = {'EUR': 1.0, 'IDR': 20149.32, 'USD': 1.1225, 'JPY': 176.99};
    return CurrencyRates(
      base: 'IDR',
      date: '2026-10-02',
      source: 'fallback',
      fetchedAt: now,
      rates: {for (final c in supportedCurrencies) c: eur[c]! / eur['IDR']!},
    );
  }
}

/// Gear fotografi untuk konverter (harga dalam rupiah).
class GearItem {
  const GearItem({
    required this.id,
    required this.name,
    required this.priceIdr,
  });

  final int id;
  final String name;
  final int priceIdr;

  factory GearItem.fromJson(Map<String, dynamic> json) => GearItem(
    id: json['id'] as int,
    name: json['name'] as String,
    priceIdr: (json['price_idr'] as num).toInt(),
  );
}
