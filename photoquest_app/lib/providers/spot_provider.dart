import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/spot.dart';
import '../data/remote/api_exception.dart';
import '../data/repositories/spot_repository.dart';

/// State halaman Explore: daftar spot, pencarian, filter kategori, dan favorit.
class SpotProvider extends ChangeNotifier {
  SpotProvider(this._repo);

  final SpotRepository _repo;

  List<Spot> spots = [];
  bool loading = false;
  String? error;
  bool fromCache = false;
  DateTime? cachedAt;

  String query = '';
  String? category; // null = semua kategori
  bool favoritesOnly = false;
  Set<int> favoriteIds = {};

  Timer? _debounce;
  int _requestSeq = 0; // untuk mengabaikan respons lama (race condition)

  /// Spot yang ditampilkan (filter "Favorit" dilakukan di sisi aplikasi).
  List<Spot> get visibleSpots => favoritesOnly
      ? spots.where((s) => favoriteIds.contains(s.id)).toList()
      : spots;

  bool isFavorite(int spotId) => favoriteIds.contains(spotId);

  /// Muat ulang daftar spot + favorit (dipanggil saat Explore dibuka).
  Future<void> refresh() => Future.wait([loadSpots(), loadFavorites()]);

  Future<void> loadSpots() async {
    final seq = ++_requestSeq;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repo.getSpots(search: query, category: category);
      if (seq != _requestSeq) return; // sudah ada pencarian yang lebih baru
      spots = result.data;
      fromCache = result.fromCache;
      cachedAt = result.cachedAt;
    } on ApiException catch (e) {
      if (seq != _requestSeq) return;
      error = e.message;
    } finally {
      if (seq == _requestSeq) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadFavorites() async {
    try {
      favoriteIds = (await _repo.favoriteIds()).data;
      notifyListeners();
    } on ApiException {
      // Favorit gagal dimuat tidak menghalangi daftar spot tampil.
    }
  }

  /// Debounce: tunggu 400 ms setelah user berhenti mengetik baru memanggil API.
  void setQuery(String value) {
    query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), loadSpots);
  }

  void setCategory(String? value) {
    if (category == value) return;
    category = value;
    loadSpots();
  }

  void setFavoritesOnly(bool value) {
    favoritesOnly = value;
    notifyListeners();
  }

  /// Toggle favorit. Mengembalikan pesan error, atau null jika berhasil.
  Future<String?> toggleFavorite(int spotId) async {
    final makeFavorite = !isFavorite(spotId);
    try {
      await _repo.setFavorite(spotId, makeFavorite);
      favoriteIds = {...favoriteIds};
      makeFavorite ? favoriteIds.add(spotId) : favoriteIds.remove(spotId);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Dipanggil saat logout: kosongkan data milik user (favorit, filter favorit).
  void clearUserState() {
    favoriteIds = {};
    favoritesOnly = false;
    notifyListeners();
  }

  /// Detail spot terbaru dari server (fallback cache).
  Future<Spot> fetchSpot(int id) async => (await _repo.getSpot(id)).data;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
