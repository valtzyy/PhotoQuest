import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';
import 'glass_surface.dart';

/// Lencana pil kaca (nomor soal, status, level). Tidak bisa ditekan.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.tone = GlassTone.yellow,
    this.icon,
  });

  final String label;
  final GlassTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = PqColors.of(context).tone(tone);
    return GlassSurface(
      tone: colors,
      radius: 999,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: colors.onColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.onColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
