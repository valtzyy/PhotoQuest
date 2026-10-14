import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';
import 'glass_surface.dart';

/// Bar progres berkilap. Nilai di luar 0..1 dijepit; NaN atau tak hingga = 0.
class GlassProgressBar extends StatelessWidget {
  const GlassProgressBar({
    super.key,
    required this.value,
    this.colors = PqPalette.tileBlue,
    this.height = 12,
  });

  final double value;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = PqColors.of(context);
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final radius = BorderRadius.circular(999);
    return Semantics(
      value: '${(v * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: radius,
          border: Border.all(color: c.panelEdge),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: glassGloss),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
