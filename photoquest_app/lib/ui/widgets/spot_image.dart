import 'package:flutter/material.dart';

import '../../data/models/spot.dart';
import 'spot_placeholder.dart';

/// Foto asli spot dari [Spot.imageUrl]. Placeholder dipakai saat belum ada URL,
/// selama memuat, atau jika gagal dimuat (offline / diblokir).
class SpotImage extends StatelessWidget {
  const SpotImage({super.key, required this.spot, this.iconSize = 40});

  final Spot spot;
  final double iconSize;

  /// Wikimedia meminta User-Agent yang jelas untuk permintaan gambar.
  static const _headers = {'User-Agent': 'PhotoQuest/1.0 (student project)'};

  @override
  Widget build(BuildContext context) {
    final placeholder = SpotPlaceholder(
      category: spot.category,
      iconSize: iconSize,
    );
    final url = spot.imageUrl;
    if (url == null || url.isEmpty) return placeholder;
    return Image.network(
      url,
      headers: _headers,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}
