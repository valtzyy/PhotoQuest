import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes.dart';
import '../../providers/auth_provider.dart';

/// Konfirmasi logout -> hapus token & cache user -> kembali ke Login.
Future<void> confirmLogout(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.logout),
      title: const Text('Logout'),
      content: const Text('Yakin ingin keluar dari PhotoQuest?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;
  await context.read<AuthProvider>().logout();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
}
