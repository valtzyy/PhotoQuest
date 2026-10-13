import 'package:flutter/material.dart';

import 'glass_surface.dart';

/// Tile ikon bergradien dengan kilap kaca (menu Home, ilustrasi state).
class GlassIconTile extends StatelessWidget {
  const GlassIconTile({
    super.key,
    required this.icon,
    required this.colors,
    this.size = 44,
  });

  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.3);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0xB3FFFFFF)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, gradient: glassGloss),
        child: Icon(icon, size: size * 0.52, color: Colors.white),
      ),
    );
  }
}
