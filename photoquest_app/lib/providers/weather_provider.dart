import 'package:flutter/foundation.dart';

import '../data/models/weather_info.dart';
import '../data/remote/api_exception.dart';
import '../data/repositories/cached_result.dart';
import '../data/repositories/weather_repository.dart';

/// State cuaca per lokasi. Hasil disimpan di memori selama aplikasi berjalan.
class WeatherProvider extends ChangeNotifier {
  WeatherProvider(this._repo);

  final WeatherRepository _repo;

  final Map<String, CachedResult<WeatherInfo>> _results = {};
  final Set<String> _loading = {};
  final Map<String, String> _errors = {};

  CachedResult<WeatherInfo>? resultFor(double lat, double lng) =>
      _results[WeatherRepository.keyFor(lat, lng)];
  bool isLoading(double lat, double lng) =>
      _loading.contains(WeatherRepository.keyFor(lat, lng));
  String? errorFor(double lat, double lng) =>
      _errors[WeatherRepository.keyFor(lat, lng)];

  /// Muat cuaca. Tanpa [force], hasil yang sudah ada di memori dipakai ulang.
  Future<CachedResult<WeatherInfo>?> load(
    double lat,
    double lng, {
    bool force = false,
  }) async {
    final key = WeatherRepository.keyFor(lat, lng);
    if (!force && _results.containsKey(key)) return _results[key];
    if (_loading.contains(key)) return _results[key];

    _loading.add(key);
    _errors.remove(key);
    notifyListeners();
    try {
      final result = await _repo.get(lat, lng);
      _results[key] = result;
      return result;
    } on ApiException catch (e) {
      _errors[key] = e.message;
      return null;
    } finally {
      _loading.remove(key);
      notifyListeners();
    }
  }
}
