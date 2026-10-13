import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';

/// Panel kaca frosted. [blur] memakai BackdropFilter, jadi pakai seperlunya
/// (bottom nav) karena berat di HP kelas bawah.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.blur = false,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool blur;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = PqColors.of(context);
    final borderRadius = BorderRadius.circular(radius);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: borderRadius,
        border: Border.all(color: c.panelEdge),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!blur) return box;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: box,
      ),
    );
  }
}
