import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';

/// Splash: memutuskan ke mana user diarahkan saat aplikasi dibuka.
///
/// 1. Tidak ada token               -> Login
/// 2. Ada token + biometrik aktif   -> prompt biometrik -> /auth/me -> Home
///    (biometrik gagal/batal        -> tawarkan login password)
/// 3. Ada token tanpa biometrik     -> /auth/me -> Home
/// 4. /auth/me 401                  -> token dihapus -> Login (ditangani interceptor)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _problem; // pesan bila biometrik gagal / server tidak terjangkau
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    // Jalankan setelah frame pertama agar context siap dipakai.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final auth = context.read<AuthProvider>();
    await auth.loadBiometricSetting();

    // (1) Belum pernah login
    if (!await auth.hasToken()) return _goTo(AppRoutes.login);

    // (2) Biometrik aktif -> wajib lolos biometrik sebelum session dibuka
    if (auth.biometricEnabled) {
      if (!await auth.isBiometricAvailable()) {
        return _showProblem('Biometrik tidak tersedia di perangkat. Silakan login dengan password.');
      }
      final bio = await auth.authenticateBiometric();
      if (!bio.success) return _showProblem(bio.message ?? 'Login biometrik gagal');
    }

    // (2)/(3) Validasi token ke server
    final result = await auth.restoreSession();
    if (!mounted) return;
    switch (result.status) {
      case RestoreStatus.online:
        return _goTo(AppRoutes.home);
      case RestoreStatus.offline:
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Mode offline: server tidak dapat dihubungi')),
        );
        return _goTo(AppRoutes.home);
      case RestoreStatus.unauthorized:
        // (4) Interceptor sudah logout & membuka Login. Jangan navigasi dua kali.
        return;
      case RestoreStatus.failed:
        return _showProblem('${result.message}\nServer: ${AppConfig.apiBaseUrl}');
    }
  }

  void _goTo(String route) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _showProblem(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_rounded, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('PhotoQuest', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Smart Photography Companion', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 32),
                if (_busy) const CircularProgressIndicator(),
                if (_problem != null) ...[
                  Text(_problem!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _bootstrap,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                  TextButton(
                    onPressed: () => _goTo(AppRoutes.login),
                    child: const Text('Login dengan password'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
