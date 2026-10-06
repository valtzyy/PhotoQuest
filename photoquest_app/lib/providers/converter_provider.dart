import 'package:flutter/foundation.dart';

import '../data/models/currency.dart';
import '../data/remote/api_exception.dart';
import '../data/repositories/cached_result.dart';
import '../data/repositories/converter_repository.dart';

/// State konverter kurs: kurs, daftar gear, dan input harga (gear atau manual).
class ConverterProvider extends ChangeNotifier {
  ConverterProvider(this._repo);

  final ConverterRepository _repo;

  CachedResult<CurrencyRates>? rates;
  List<GearItem> gear = [];
  bool loading = false;
  String? error; // gagal memuat daftar gear (kurs selalu punya fallback)

  /// Input: jumlah + mata uangnya. Default harga gear termurah (diisi setelah load).
  double amount = 0;
  String currency = 'IDR';
  GearItem? selectedGear;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      rates = await _repo.rates();
      try {
        gear = (await _repo.gear()).data;
      } on ApiException catch (e) {
        error = e.message; // konverter manual tetap bisa dipakai
      }
      if (selectedGear == null && amount == 0 && gear.isNotEmpty) {
        selectGear(gear.first);
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectGear(GearItem? item) {
    selectedGear = item;
    if (item != null) {
      amount = item.priceIdr.toDouble();
      currency = 'IDR';
    }
    notifyListeners();
  }

  /// Input manual: memilih jumlah/mata uang sendiri membatalkan pilihan gear.
  void setManual({double? amount, String? currency}) {
    if (amount != null) this.amount = amount;
    if (currency != null) this.currency = currency;
    selectedGear = null;
    notifyListeners();
  }

  /// Nilai [amount] dalam setiap mata uang yang didukung.
  Map<String, double> get converted {
    final r = rates?.data;
    if (r == null) return {};
    return {
      for (final c in supportedCurrencies) c: r.convert(amount, currency, c),
    };
  }
}
