import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/pq_colors.dart';
import '../../data/models/challenge_attempt.dart';
import '../../data/remote/api_exception.dart';
import '../../data/repositories/cached_result.dart';
import '../../data/repositories/profile_repository.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../widgets/state_views.dart';
import '../widgets/theme_mode_tile.dart';
import '../widgets/user_avatar.dart';

/// Tab Profil: foto profil, nama, email, toggle biometrik, riwayat challenge.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.shown});

  /// Bertambah setiap kali tab Profil dibuka (dari MainShell). Tab dijaga oleh
  /// IndexedStack, jadi tanpa sinyal ini riwayat hanya dimuat sekali.
  final ValueListenable<int>? shown;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;

  // State riwayat challenge
  bool _loadingHistory = true;
  String? _historyError;
  CachedResult<List<ChallengeAttempt>>? _history;

  /// Diganti agar UserAvatar dibuat ulang (muat ulang foto) saat refresh.
  int _avatarEpoch = 0;

  @override
  void initState() {
    super.initState();
    widget.shown?.addListener(_onShown);
    _loadHistory();
  }

  @override
  void dispose() {
    widget.shown?.removeListener(_onShown);
    super.dispose();
  }

  void _onShown() => _loadHistory(silent: true);

  Future<void> _refresh() {
    setState(() => _avatarEpoch++);
    return _loadHistory();
  }

  /// [silent]: perbarui tanpa spinner bila riwayat sudah tampil.
  Future<void> _loadHistory({bool silent = false}) async {
    setState(() {
      _loadingHistory = !silent || _history == null;
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

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    // Pengguna memilih bagian foto (rasio 1:1, bingkai bulat) sebelum diunggah.
    // Hasil diperkecil ke 800 px agar di bawah batas 2 MB backend.
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 800,
      maxHeight: 800,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan foto profil',
          toolbarColor: PqPalette.blue,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: PqPalette.blue,
          cropStyle: CropStyle.circle,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          lockAspectRatio: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return; // dibatalkan: foto lama tetap

    setState(() => _uploading = true);
    try {
      final user = await context.read<ProfileRepository>().uploadPhoto(
        cropped.path,
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
    // Controller dimiliki oleh _EditNameDialog (bukan dibuat di sini), supaya
    // baru di-dispose setelah dialog benar-benar hilang dari layar.
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialName: current),
    );
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

  Future<void> _testNotification() async {
    final r = await context.read<NotificationService>().scheduleTest();
    if (!mounted) return;
    _snack(
      r.success
          ? 'Notifikasi uji akan muncul ±10 detik lagi (boleh keluar dari aplikasi).'
          : r.error!,
    );
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profil')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Foto profil + tombol ganti
            Center(
              child: Stack(
                children: [
                  UserAvatar(
                    key: ValueKey(_avatarEpoch),
                    user: user,
                    radius: 56,
                  ),
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
                  const ThemeModeTile(),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Uji Notifikasi (10 detik)'),
                    subtitle: const Text('Demo notifikasi terjadwal'),
                    onTap: _testNotification,
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
                    ? PqPalette.success
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

/// Dialog ubah nama.
///
/// Dibuat sebagai StatefulWidget agar TextEditingController dibuang di dispose()
/// milik dialog ini. Jika controller di-dispose tepat setelah showDialog() selesai,
/// dialog yang masih menjalankan animasi menutup akan memakai controller yang
/// sudah dibuang -> error "_dependents.isEmpty" (layar merah).
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah nama'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _save(),
          decoration: const InputDecoration(labelText: 'Nama'),
          validator: (v) =>
              (v?.trim().length ?? 0) < 2 ? 'Nama minimal 2 karakter' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
