import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';
import 'glass_surface.dart';

/// Area kaca yang bisa ditekan: tile menu, jawaban kuis, kartu.
/// Jika [onTap] null, area tidak bereaksi tetapi tetap tampil normal.
class GlassPressable extends StatefulWidget {
  const GlassPressable({
    super.key,
    required this.child,
    this.onTap,
    this.tone = GlassTone.neutral,
    this.radius = 16,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final GlassTone tone;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final tone = PqColors.of(context).tone(widget.tone);
    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (widget.tone != GlassTone.neutral) {
      content = onColorTheme(context, tone.onColor, content);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: widget.onTap,
        child: GlassSurface(
          tone: tone,
          radius: widget.radius,
          pressed: _down,
          haptic: true,
          child: content,
        ),
      ),
    );
  }
}

/// Tema teks dan ikon berwarna [on] untuk konten di atas permukaan berwarna.
Widget onColorTheme(BuildContext context, Color on, Widget child) {
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      textTheme: theme.textTheme.apply(bodyColor: on, displayColor: on),
      iconTheme: theme.iconTheme.copyWith(color: on),
      listTileTheme: theme.listTileTheme.copyWith(textColor: on, iconColor: on),
      dividerTheme: theme.dividerTheme.copyWith(
        color: on.withValues(alpha: 0.3),
      ),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: on),
      child: IconTheme.merge(
        data: IconThemeData(color: on),
        child: child,
      ),
    ),
  );
}
