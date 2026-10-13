import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pq_colors.dart';

/// Kilap kaca: putih tegas di separuh atas, terputus di tengah.
const glassGloss = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x6BFFFFFF),
    Color(0x1AFFFFFF),
    Color(0x00FFFFFF),
    Color(0x00FFFFFF),
  ],
  stops: [0, 0.48, 0.52, 1],
);

/// Permukaan kaca 3D: gradien semi-transparan, kilap, tepi tipis, dan bibir
/// di bawah. Saat [pressed], permukaan turun sedalam [lip] lalu memantul
/// kembali ketika dilepas.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.tone,
    required this.child,
    this.pressed = false,
    this.radius = 16,
    this.haptic = false,
    this.dimmed = false,
  });

  final GlassToneColors tone;
  final Widget child;
  final bool pressed;
  final double radius;

  /// Getar ringan setiap kali berubah menjadi ditekan.
  final bool haptic;

  /// Tampilan redup untuk tombol nonaktif.
  final bool dimmed;

  static const double lip = 3;
  static const pressDuration = Duration(milliseconds: 50);
  static const releaseDuration = Duration(milliseconds: 220);
  static const releaseCurve = Cubic(0.3, 1.8, 0.5, 1);

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  @override
  void didUpdateWidget(GlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.haptic && widget.pressed && !oldWidget.pressed) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final radius = BorderRadius.circular(widget.radius);
    final surface = TweenAnimationBuilder<double>(
      tween: Tween(end: widget.pressed ? 1 : 0),
      duration: widget.pressed
          ? GlassSurface.pressDuration
          : GlassSurface.releaseDuration,
      curve: widget.pressed ? Curves.easeOut : GlassSurface.releaseCurve,
      builder: (context, t, child) => CustomPaint(
        painter: _LipPainter(t: t, radius: widget.radius, lipColor: tone.lip),
        child: Transform.translate(
          offset: Offset(0, GlassSurface.lip * t),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: tone.edge),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tone.top, tone.bottom],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, gradient: glassGloss),
          child: widget.child,
        ),
      ),
    );
    return widget.dimmed ? Opacity(opacity: 0.55, child: surface) : surface;
  }
}

/// Menggambar bibir 3D dan bayangan lembut hanya di luar muka tombol,
/// supaya warnanya tidak tembus ke kaca yang semi-transparan.
class _LipPainter extends CustomPainter {
  _LipPainter({required this.t, required this.radius, required this.lipColor});

  final double t;
  final double radius;
  final Color lipColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius);
    final face = RRect.fromRectAndRadius(
      Offset(0, GlassSurface.lip * t) & size,
      r,
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()
          ..addRect(Rect.fromLTWH(-24, -24, size.width + 48, size.height + 48)),
        Path()..addRRect(face),
      ),
    );
    final lift = (1 - t).clamp(0.0, 1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset(0, 4 + 2 * lift) & size, r),
      Paint()
        ..color = const Color(0x14284678)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + 4 * lift),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Offset(0, GlassSurface.lip) & size, r),
      Paint()..color = lipColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LipPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.radius != radius ||
      oldDelegate.lipColor != lipColor;
}
