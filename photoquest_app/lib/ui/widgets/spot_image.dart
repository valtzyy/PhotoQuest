import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/spot.dart';
import 'spot_placeholder.dart';

/// Foto asli spot dari [Spot.imageUrl]. Placeholder dipakai saat belum ada URL,
/// selama memuat, atau jika gagal dimuat (offline / diblokir).
///
/// Flutter tidak memuat ulang gambar yang gagal selama alamatnya tidak berubah,
/// jadi bila gagal (mis. internet mati lalu hidup lagi) widget mencoba lagi sendiri
/// dengan jeda yang makin panjang, tanpa perlu keluar dari layar.
class SpotImage extends StatefulWidget {
  const SpotImage({super.key, required this.spot, this.iconSize = 40});

  final Spot spot;
  final double iconSize;

  /// Wikimedia meminta User-Agent yang jelas untuk permintaan gambar.
  static const headers = {'User-Agent': 'PhotoQuest/1.0 (student project)'};

  /// Jeda percobaan ulang pertama (menjadi 2x lipat tiap percobaan).
  static const retryBaseDelay = Duration(seconds: 2);
  static const maxRetries = 5;

  @override
  State<SpotImage> createState() => _SpotImageState();
}

class _SpotImageState extends State<SpotImage> {
  int _attempt = 0;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(SpotImage old) {
    super.didUpdateWidget(old);
    if (old.spot.imageUrl != widget.spot.imageUrl) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry(String url) {
    if (_retryTimer != null || _attempt >= SpotImage.maxRetries) return;
    final delay = SpotImage.retryBaseDelay * (1 << _attempt);
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!mounted) return;
      // Buang catatan gagal dari cache gambar, lalu bangun ulang dengan kunci baru.
      NetworkImage(url).evict();
      setState(() => _attempt++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final placeholder = SpotPlaceholder(
      category: spot.category,
      iconSize: widget.iconSize,
    );
    final url = spot.imageUrl;
    if (url == null || url.isEmpty) return placeholder;
    return Image.network(
      url,
      key: ValueKey('$url#$_attempt'),
      headers: SpotImage.headers,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (context, error, stack) {
        _scheduleRetry(url);
        return placeholder;
      },
    );
  }
}
