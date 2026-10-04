import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/geo_utils.dart';
import '../data/local/db_helper.dart';
import '../data/models/spot.dart';
import '../services/location_service.dart';

/// Posisi user untuk LBS (spot terdekat, jarak, peta).
///
/// - Posisi GPS asli bila izin diberikan dan GPS berhasil.
/// - Lokasi demo (Tugu Jogja) jika user memilihnya ATAU GPS gagal/ditolak,
///   agar demo di kelas tetap jalan walau tidak sedang di Yogyakarta.
class LocationProvider extends ChangeNotifier {
  LocationProvider(this._service, this._db);

  final LocationService _service;
  final DbHelper _db;

  static const demoPoint = LatLng(AppConstants.demoLat, AppConstants.demoLng);
  static const _kUseDemo = 'use_demo_location';
  static const _kLastLat = 'last_lat';
  static const _kLastLng = 'last_lng';

  LatLng? position;
  bool isDemo = false; // posisi saat ini berasal dari lokasi demo?
  bool useDemo = false; // preferensi user: selalu pakai lokasi demo
  bool loading = false;
  String? message; // alasan memakai lokasi demo / info status

  bool _initialized = false;

  /// Muat preferensi & posisi terakhir dari sqflite (tabel settings).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    useDemo = await _db.getSetting(_kUseDemo) == 'true';
    if (useDemo) {
      _setDemo('Memakai lokasi demo (Tugu Jogja)');
      return;
    }
    final lat = double.tryParse(await _db.getSetting(_kLastLat) ?? '');
    final lng = double.tryParse(await _db.getSetting(_kLastLng) ?? '');
    if (lat != null && lng != null) {
      position = LatLng(lat, lng);
      message = 'Posisi terakhir yang tersimpan';
      notifyListeners();
    }
  }

  Future<bool> needsPermissionRequest() => _service.needsPermissionRequest();
  Future<bool> hasPermission() => _service.hasPermission();
  Future<bool> openAppSettings() => _service.openAppSettings();

  /// Ambil lokasi GPS. Jika gagal -> otomatis pakai lokasi demo + pesan alasannya.
  Future<void> locate({bool requestPermission = true}) async {
    if (useDemo) return _setDemo('Memakai lokasi demo (Tugu Jogja)');
    loading = true;
    notifyListeners();
    try {
      final p = await _service.currentPosition(request: requestPermission);
      position = LatLng(p.latitude, p.longitude);
      isDemo = false;
      message = null;
      await _db.setSetting(_kLastLat, '${p.latitude}');
      await _db.setSetting(_kLastLng, '${p.longitude}');
    } on LocationFailure catch (e) {
      _setDemo(
        '${e.message}. Memakai lokasi demo (Tugu Jogja).',
        notify: false,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Toggle "Gunakan lokasi demo" (disimpan agar tetap aktif saat app dibuka lagi).
  Future<void> setUseDemo(bool value) async {
    useDemo = value;
    await _db.setSetting(_kUseDemo, '$value');
    if (value) {
      _setDemo('Memakai lokasi demo (Tugu Jogja)');
    } else {
      await locate();
    }
  }

  void _setDemo(String reason, {bool notify = true}) {
    position = demoPoint;
    isDemo = true;
    message = reason;
    if (notify) notifyListeners();
  }

  /// Jarak (km) dari posisi user ke spot; null jika posisi belum diketahui.
  double? distanceTo(Spot spot) {
    final p = position;
    if (p == null) return null;
    return GeoUtils.haversineKm(
      p.latitude,
      p.longitude,
      spot.latitude,
      spot.longitude,
    );
  }

  /// Urutkan spot dari yang terdekat (tanpa posisi -> urutan asli).
  List<Spot> sortByDistance(List<Spot> spots) {
    if (position == null) return spots;
    final sorted = [...spots];
    sorted.sort((a, b) => distanceTo(a)!.compareTo(distanceTo(b)!));
    return sorted;
  }
}
