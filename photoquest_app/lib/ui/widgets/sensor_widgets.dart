import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/sensor_math.dart';

const _levelColor = Color(0xFF2E7D32); // hijau
const _tiltColor = Color(0xFFEF6C00); // oranye

/// Teks status level: "Rata ✓" atau "Miring +X°".
String levelLabel(double roll) {
  if (isLevel(roll)) return 'Rata ✓';
  final sign = roll > 0 ? '+' : '';
  return 'Miring $sign${Formatters.decimal(roll, digits: 1)}°';
}

Color levelColor(double roll) => isLevel(roll) ? _levelColor : _tiltColor;

Color stabilityColor(Stability s) => switch (s) {
  Stability.stable => _levelColor,
  Stability.slightShake => const Color(0xFFF9A825), // kuning
  Stability.shaky => const Color(0xFFC62828), // merah
};

/// Waterpas tabung: gelembung bergeser ke sisi HP yang lebih tinggi.
class BubbleLevel extends StatelessWidget {
  const BubbleLevel({super.key, required this.roll, this.maxDeg = 20});

  final double roll;

  /// Kemiringan yang membuat gelembung mentok di ujung tabung.
  final double maxDeg;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(roll);
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 56.0;
        const bubble = 44.0;
        final width = constraints.maxWidth;
        final travel = (width - bubble) / 2; // jarak maksimum dari tengah
        // Roll negatif = sisi kanan lebih rendah -> gelembung ke kiri (sisi yang tinggi).
        final offset = (roll / maxDeg).clamp(-1.0, 1.0) * travel;
        // Penanda zona "rata" (±2°) di tengah tabung.
        final zone = (levelToleranceDeg / maxDeg) * travel + bubble / 2;

        return SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(color: color, width: 2),
                ),
              ),
              // Garis batas toleransi ±2°
              for (final dx in [-zone, zone])
                Transform.translate(
                  offset: Offset(dx, 0),
                  child: Container(width: 2, height: height - 12, color: color),
                ),
              Transform.translate(
                offset: Offset(offset, 0),
                child: Container(
                  width: bubble,
                  height: bubble,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bar stabilitas: panjang sebanding magnitude gyroscope (0–1 rad/s).
class StabilityBar extends StatelessWidget {
  const StabilityBar({super.key, required this.magnitude});

  final double magnitude;

  @override
  Widget build(BuildContext context) {
    final s = Stability.classify(magnitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: magnitude.clamp(0.0, 1.0),
            minHeight: 16,
            color: stabilityColor(s),
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('0'), Text('≥ 1 rad/s')],
        ),
        const SizedBox(height: 4),
        Text(
          'Stabil < 0,15 · Sedikit goyang 0,15–0,5 · Goyang > 0,5',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
