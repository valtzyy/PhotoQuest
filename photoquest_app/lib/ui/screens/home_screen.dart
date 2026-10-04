import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes.dart';
import '../../providers/auth_provider.dart';

/// Home SEMENTARA untuk Fase 2 (menguji session, biometrik, dan logout).
/// Di Fase 3 diganti dengan Bottom Navigation: Home | Profil | Saran & Kesan | Logout.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin ingin keluar dari PhotoQuest?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Future<void> _toggleBiometric(BuildContext context, bool value) async {
    final error = await context.read<AuthProvider>().setBiometricEnabled(value);
    if (!context.mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('PhotoQuest')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.isOffline)
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_off),
                title: Text('Mode offline'),
                subtitle: Text('Server tidak dapat dihubungi, memakai data tersimpan.'),
              ),
            ),
          Text('Halo, ${user?.name ?? '-'}', style: Theme.of(context).textTheme.headlineSmall),
          Text(user?.email ?? ''),
          const SizedBox(height: 16),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Login biometrik'),
            subtitle: const Text('Buka aplikasi dengan sidik jari/wajah'),
            value: auth.biometricEnabled,
            onChanged: (v) => _toggleBiometric(context, v),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
