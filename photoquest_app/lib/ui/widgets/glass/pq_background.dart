import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';

/// Latar aplikasi: warna dasar dengan bercak warna radial yang lembut.
/// Dipakai sebagai PqBackground(child: Scaffold(backgroundColor: Colors.transparent)).
class PqBackground extends StatelessWidget {
  const PqBackground({super.key, required this.child});

  final Widget child;

  static const _centers = [
    Alignment(-0.8, -0.85),
    Alignment(0.9, -0.2),
    Alignment(-0.6, 0.8),
  ];

  @override
  Widget build(BuildContext context) {
    final c = PqColors.of(context);
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: c.bgBase)),
        for (var i = 0; i < c.bgBlobs.length && i < _centers.length; i++)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: _centers[i],
                  radius: 0.9,
                  colors: [c.bgBlobs[i], c.bgBlobs[i].withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
