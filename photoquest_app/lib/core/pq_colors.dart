import 'package:flutter/material.dart';

/// Varian warna permukaan kaca (tombol, tile, pil).
enum GlassTone { neutral, blue, yellow, red, green }

/// Warna satu varian kaca: gradien atas-bawah, bibir 3D, tepi, dan teks di atasnya.
@immutable
class GlassToneColors {
  const GlassToneColors({
    required this.top,
    required this.bottom,
    required this.lip,
    required this.edge,
    required this.onColor,
  });

  final Color top;
  final Color bottom;
  final Color lip;
  final Color edge;
  final Color onColor;
}

/// Konstanta palet yang sama di mode terang dan gelap.
abstract final class PqPalette {
  static const blue = Color(0xFF36A6E6);
  static const success = Color(0xFF249653);
  static const okay = Color(0xFF6CB33F);
  static const warning = Color(0xFFE0A410);
  static const gold = Color(0xFFF5AA00);
  static const orange = Color(0xFFF27A32);
  static const danger = Color(0xFFCC3A33);

  static const blueTone = GlassToneColors(
    top: Color(0xB878D6FA),
    bottom: Color(0xAD36A6E6),
    lip: Color(0x802385C4),
    edge: Color(0xCCC8EEFF),
    onColor: Colors.white,
  );
  static const yellowTone = GlassToneColors(
    top: Color(0xC7FFE896),
    bottom: Color(0xADFFCB46),
    lip: Color(0x73D69E14),
    edge: Color(0xD9FFF5D2),
    onColor: Color(0xFF7A5A12),
  );
  static const redTone = GlassToneColors(
    top: Color(0xBFFF968C),
    bottom: Color(0xADF25B53),
    lip: Color(0x73CC3A33),
    edge: Color(0xD9FFD7D2),
    onColor: Colors.white,
  );
  static const greenTone = GlassToneColors(
    top: Color(0xBF8BEBAE),
    bottom: Color(0xAD38C371),
    lip: Color(0x73249653),
    edge: Color(0xD9D2FAE1),
    onColor: Colors.white,
  );

  static const tileRed = [Color(0xFFFF968C), Color(0xFFF25B53)];
  static const tileBlue = [Color(0xFF78D6FA), Color(0xFF36A6E6)];
  static const tileYellow = [Color(0xFFFFD95A), Color(0xFFF5AA00)];
  static const tilePurple = [Color(0xFFB9A8FF), Color(0xFF7B62E8)];
  static const tileGreen = [Color(0xFF8BEBAE), Color(0xFF38C371)];
  static const tileOrange = [Color(0xFFFFB083), Color(0xFFF27A32)];

  static const holo = [
    Color(0xD9FFE68C),
    Color(0xCCA6E8FF),
    Color(0xCCE7C2FF),
    Color(0xD9FFE68C),
  ];
}

/// Token warna PhotoQuest yang berbeda antara mode terang dan gelap.
@immutable
class PqColors extends ThemeExtension<PqColors> {
  const PqColors({
    required this.bgBase,
    required this.bgBlobs,
    required this.text,
    required this.heading,
    required this.subtle,
    required this.panel,
    required this.panelEdge,
    required this.neutral,
    required this.holoInnerTop,
    required this.holoInnerBottom,
  });

  final Color bgBase;
  final List<Color> bgBlobs;
  final Color text;
  final Color heading;
  final Color subtle;
  final Color panel;
  final Color panelEdge;
  final GlassToneColors neutral;
  final Color holoInnerTop;
  final Color holoInnerBottom;

  static const light = PqColors(
    bgBase: Color(0xFFF2F7FD),
    bgBlobs: [Color(0xFFC6E6FF), Color(0xFFFFE4BD), Color(0xFFDDD3FF)],
    text: Color(0xFF56627A),
    heading: Color(0xFF424E66),
    subtle: Color(0xFF8F9AB0),
    panel: Color(0x8CFFFFFF),
    panelEdge: Color(0xE6FFFFFF),
    neutral: GlassToneColors(
      top: Color(0x9EFFFFFF),
      bottom: Color(0x6BECF3FB),
      lip: Color(0x7396AED0),
      edge: Color(0xD9FFFFFF),
      onColor: Color(0xFF56627A),
    ),
    holoInnerTop: Color(0xF2FFFCF0),
    holoInnerBottom: Color(0xD9FFF3D2),
  );

  static const dark = PqColors(
    bgBase: Color(0xFF0F1729),
    bgBlobs: [Color(0xFF1E3A66), Color(0xFF3A2A55)],
    text: Color(0xFFB9C5DA),
    heading: Color(0xFFDCE5F4),
    subtle: Color(0xFF8796B3),
    panel: Color(0x7328385A),
    panelEdge: Color(0x1FFFFFFF),
    neutral: GlassToneColors(
      top: Color(0x7350648C),
      bottom: Color(0x59324469),
      lip: Color(0x800A101E),
      edge: Color(0x29FFFFFF),
      onColor: Color(0xFFB9C5DA),
    ),
    holoInnerTop: Color(0xCC2A3A5C),
    holoInnerBottom: Color(0xCC24334F),
  );

  /// Token dari theme aktif. Jika theme tidak memasang extension ini
  /// (misalnya MaterialApp polos di test), dipilih sesuai brightness.
  static PqColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PqColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  GlassToneColors tone(GlassTone tone) => switch (tone) {
    GlassTone.neutral => neutral,
    GlassTone.blue => PqPalette.blueTone,
    GlassTone.yellow => PqPalette.yellowTone,
    GlassTone.red => PqPalette.redTone,
    GlassTone.green => PqPalette.greenTone,
  };

  @override
  PqColors copyWith({
    Color? bgBase,
    List<Color>? bgBlobs,
    Color? text,
    Color? heading,
    Color? subtle,
    Color? panel,
    Color? panelEdge,
    GlassToneColors? neutral,
    Color? holoInnerTop,
    Color? holoInnerBottom,
  }) => PqColors(
    bgBase: bgBase ?? this.bgBase,
    bgBlobs: bgBlobs ?? this.bgBlobs,
    text: text ?? this.text,
    heading: heading ?? this.heading,
    subtle: subtle ?? this.subtle,
    panel: panel ?? this.panel,
    panelEdge: panelEdge ?? this.panelEdge,
    neutral: neutral ?? this.neutral,
    holoInnerTop: holoInnerTop ?? this.holoInnerTop,
    holoInnerBottom: holoInnerBottom ?? this.holoInnerBottom,
  );

  // Perpindahan terang-gelap cukup berganti di tengah animasi.
  @override
  PqColors lerp(covariant PqColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
