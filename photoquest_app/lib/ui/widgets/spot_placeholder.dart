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
    'landscape': [Color(0xFFFFB36B), Color(0xFFFF6B4A)],
    'architecture': [Color(0xFFB9A8FF), Color(0xFF7B62E8)],
    'street': [Color(0xFF78D6FA), Color(0xFF36A6E6)],
    'nature': [Color(0xFF8BEBAE), Color(0xFF38C371)],
    'culture': [Color(0xFFFF968C), Color(0xFFF25B53)],
  };

  @override
  Widget build(BuildContext context) {
    final colors =
        _colors[category] ?? const [Color(0xFFB4C2D6), Color(0xFF8F9AB0)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
