import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Setelah login password pertama: tawarkan "Aktifkan login biometrik?".
/// Hanya ditampilkan sekali dan hanya jika perangkat mendukung biometrik.
Future<void> offerBiometricIfNeeded(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  if (!await auth.shouldOfferBiometric()) return;
  await auth.markBiometricAsked();
  if (!context.mounted) return;

  final enable = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.fingerprint, size: 40),
      title: const Text('Aktifkan login biometrik?'),
      content: const Text(
        'Lain kali Anda cukup memakai sidik jari/wajah untuk membuka PhotoQuest. '
        'Pengaturan ini bisa diubah di halaman Profil.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aktifkan')),
      ],
    ),
  );
  if (enable != true || !context.mounted) return;

  final error = await auth.setBiometricEnabled(true);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error ?? 'Login biometrik aktif')),
  );
}
