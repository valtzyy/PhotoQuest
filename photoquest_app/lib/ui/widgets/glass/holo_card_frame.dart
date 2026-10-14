import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';
import 'glass_pressable.dart';

/// Bingkai kartu koleksi: cincin gradien holo, isi krem, efek tekan 3D.
class HoloCardFrame extends StatelessWidget {
  const HoloCardFrame({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = PqColors.of(context);
    return GlassPressable(
      onTap: onTap,
      radius: 20,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: PqPalette.holo,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xE6FFFFFF)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.holoInnerTop, c.holoInnerBottom],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
