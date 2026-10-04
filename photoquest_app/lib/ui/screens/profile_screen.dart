import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/challenge_attempt.dart';
import '../../data/remote/api_exception.dart';
import '../../data/repositories/cached_result.dart';
import '../../data/repositories/profile_repository.dart';
import '../../providers/auth_provider.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

/// Tab Profil: foto profil, nama, email, toggle biometrik, riwayat challenge.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;

  // State riwayat challenge
  bool _loadingHistory = true;
  String? _historyError;
  CachedResult<List<ChallengeAttempt>>? _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final result = await context.read<ProfileRepository>().challengeHistory();
      if (mounted) setState(() => _history = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _historyError = e.message);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  // ------------------------------------------------------------ foto profil
  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Perkecil gambar sebelum upload agar di bawah batas 2 MB backend.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final user = await context.read<ProfileRepository>().uploadPhoto(
        picked.path,
      );
      if (!mounted) return;
      await context.read<AuthProvider>().updateUser(user);
      _snack('Foto profil diperbarui');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ------------------------------------------------------------ ubah nama
  Future<void> _editName(String current) async {
    final controller = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah nama'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama'),
            validator: (v) =>
                (v?.trim().length ?? 0) < 2 ? 'Nama minimal 2 karakter' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName == current || !mounted) return;

    try {
      final user = await context.read<ProfileRepository>().updateName(newName);
      if (!mounted) return;
      await context.read<AuthProvider>().updateUser(user);
      _snack('Nama diperbarui');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final error = await context.read<AuthProvider>().setBiometricEnabled(value);
    if (error != null && mounted) _snack(error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Foto profil + tombol ganti
            Center(
              child: Stack(
                children: [
                  UserAvatar(user: user, radius: 56),
                  if (_uploading)
                    const Positioned.fill(child: CircularProgressIndicator()),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: 'Ganti foto',
                      onPressed: _uploading ? null : _changePhoto,
                      icon: const Icon(Icons.camera_alt, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(user?.name ?? '-'),
                    subtitle: const Text('Nama'),
                    trailing: IconButton(
                      tooltip: 'Ubah nama',
                      icon: const Icon(Icons.edit),
                      onPressed: user == null
                          ? null
                          : () => _editName(user.name),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: Text(user?.email ?? '-'),
                    subtitle: const Text('Email'),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Login biometrik'),
                    subtitle: const Text(
                      'Buka aplikasi dengan sidik jari/wajah',
                    ),
                    value: auth.biometricEnabled,
                    onChanged: _toggleBiometric,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Riwayat Steady Challenge',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) return const LoadingView();
    if (_historyError != null) {
      return ErrorView(message: _historyError!, onRetry: _loadHistory);
    }
    final result = _history!;
    if (result.data.isEmpty) {
      return const EmptyView(
        message: 'Belum ada percobaan.\nCoba Steady Challenge dari menu Home.',
        icon: Icons.sports_esports_outlined,
      );
    }
    // Riwayat singkat: 5 percobaan terakhir
    return Column(
      children: [
        if (result.fromCache) OfflineBanner(cachedAt: result.cachedAt),
        for (final a in result.data.take(5))
          Card(
            child: ListTile(
              leading: Icon(
                a.success ? Icons.check_circle : Icons.cancel,
                color: a.success
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(a.success ? 'Berhasil' : 'Gagal'),
              subtitle: Text(
                'Tahan ${Formatters.decimal(a.holdSeconds, digits: 1)} dtk · '
                'miring ${Formatters.decimal(a.avgTilt, digits: 1)}° · '
                'goyang ${Formatters.decimal(a.avgShake)} rad/s\n'
                '${Formatters.dateTime(a.createdAt)}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }
}
