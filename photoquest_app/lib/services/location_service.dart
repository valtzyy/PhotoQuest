import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/config.dart';

/// Alasan lokasi GPS tidak bisa didapat (agar UI bisa menjelaskan ke user).
class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Pembungkus geolocator: cek layanan lokasi, izin, lalu ambil posisi GPS.
class LocationService {
  /// true jika izin belum pernah diminta / ditolak sekali (boleh minta lagi).
  /// Dipakai UI untuk menampilkan penjelasan sebelum dialog izin sistem muncul.
  Future<bool> needsPermissionRequest() async =>
      await Geolocator.checkPermission() == LocationPermission.denied;

  Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  /// Ambil posisi saat ini. Melempar [LocationFailure] jika gagal.
  Future<Position> currentPosition({bool request = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure('GPS/layanan lokasi di HP sedang mati');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure('Izin lokasi ditolak');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Izin lokasi ditolak permanen. Aktifkan lewat Pengaturan aplikasi.',
      );
    }

    try {
      // Batas waktu 8 detik agar tidak menunggu GPS terlalu lama (mis. di dalam ruangan).
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: AppConfig.requestTimeout,
        ),
      );
    } on TimeoutException {
      // Fallback: posisi terakhir yang diketahui sistem (jika ada).
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const LocationFailure('GPS tidak mendapat sinyal dalam 8 detik');
    } catch (e) {
      throw LocationFailure('Gagal membaca lokasi: $e');
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
