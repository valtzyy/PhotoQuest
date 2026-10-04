import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/user.dart';
import '../../data/repositories/profile_repository.dart';

/// Foto profil bulat. Foto diambil lewat dio (butuh JWT), lalu ditampilkan
/// dengan Image.memory. Jika belum ada foto / gagal, tampilkan inisial nama.
class UserAvatar extends StatefulWidget {
  const UserAvatar({super.key, required this.user, this.radius = 28});

  final User? user;
  final double radius;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  // Cache sederhana di memori agar foto tidak diunduh ulang setiap pindah tab.
  static final Map<String, Uint8List> _memoryCache = {};
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // photo_url berubah (?v=...) setelah upload -> muat ulang.
    if (oldWidget.user?.photoUrl != widget.user?.photoUrl) _load();
  }

  Future<void> _load() async {
    final url = widget.user?.photoUrl;
    if (url == null) {
      setState(() => _bytes = null);
      return;
    }
    if (_memoryCache.containsKey(url)) {
      setState(() => _bytes = _memoryCache[url]);
      return;
    }
    try {
      final bytes = await context.read<ProfileRepository>().fetchPhoto(url);
      _memoryCache[url] = bytes;
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _bytes = null); // fallback ke inisial
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user?.name.trim() ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: _bytes == null ? null : MemoryImage(_bytes!),
      child: _bytes == null
          ? Text(initial, style: TextStyle(fontSize: widget.radius * 0.8))
          : null,
    );
  }
}
