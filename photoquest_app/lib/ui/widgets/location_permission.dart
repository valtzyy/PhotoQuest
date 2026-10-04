import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/location_provider.dart';

/// Minta lokasi dengan penjelasan terlebih dahulu (sebelum dialog izin sistem).
/// Jika user menolak / GPS gagal, LocationProvider otomatis memakai lokasi demo.
Future<void> requestLocationWithRationale(BuildContext context) async {
  final loc = context.read<LocationProvider>();

  if (!loc.useDemo && await loc.needsPermissionRequest()) {
    if (!context.mounted) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on, size: 40),
        title: const Text('Izinkan akses lokasi?'),
        content: const Text(
          'PhotoQuest memakai lokasi Anda untuk menghitung jarak dan menampilkan '
          'spot foto terdekat di peta. Lokasi hanya diproses di HP dan tidak dikirim ke server.\n\n'
          'Jika tidak diizinkan, aplikasi memakai lokasi demo (Tugu Jogja).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Pakai lokasi demo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Izinkan'),
          ),
        ],
      ),
    );
    // Tidak diizinkan -> locate() tanpa meminta izin -> gagal -> lokasi demo.
    await loc.locate(requestPermission: allow == true);
    return;
  }
  await loc.locate();
}
