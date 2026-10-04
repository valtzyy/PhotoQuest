import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Placeholder gambar spot (image_url masih NULL): gradien + ikon kategori.
class SpotPlaceholder extends StatelessWidget {
  const SpotPlaceholder({
    super.key,
    required this.category,
    this.iconSize = 40,
  });

  final String category;
  final double iconSize;

  static const _colors = {
    'landscape': [Color(0xFFF2994A), Color(0xFFF2C94C)],
    'architecture': [Color(0xFF8E6E53), Color(0xFFD1A684)],
    'street': [Color(0xFF5B6C8F), Color(0xFF9AA8C7)],
    'nature': [Color(0xFF3F8F5B), Color(0xFF9BD3A8)],
    'culture': [Color(0xFFB0413E), Color(0xFFE79A79)],
  };

  @override
  Widget build(BuildContext context) {
    final colors = _colors[category] ?? const [Colors.grey, Colors.blueGrey];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Labels.categoryIcon(category),
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
