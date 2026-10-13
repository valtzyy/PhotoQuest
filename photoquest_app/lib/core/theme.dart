import 'package:flutter/material.dart';

import '../ui/widgets/glass/glass_surface.dart';
import 'pq_colors.dart';

/// Tema "glassy TCG": tombol kaca 3D, panel frosted, teks abu-abu kebiruan.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'MPLUSRounded1c';

  static ThemeData get light => _build(PqColors.light, Brightness.light);

  static ThemeData get dark => _build(PqColors.dark, Brightness.dark);

  static ThemeData _build(PqColors c, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: PqPalette.blue,
          brightness: brightness,
        ).copyWith(
          primary: isLight ? const Color(0xFF2E9BDB) : const Color(0xFF78D6FA),
          onPrimary: isLight ? Colors.white : const Color(0xFF0F1729),
          primaryContainer: isLight
              ? const Color(0xFFD9F1FD)
              : const Color(0xFF1E3A66),
          onPrimaryContainer: c.heading,
          secondary: PqPalette.gold,
          secondaryContainer: isLight
              ? const Color(0xFFFFF1C7)
              : const Color(0xFF4A3A10),
          onSecondaryContainer: c.heading,
          tertiary: PqPalette.success,
          tertiaryContainer: isLight
              ? const Color(0xFFDDF6E6)
              : const Color(0xFF1D4A31),
          onTertiaryContainer: c.heading,
          error: PqPalette.danger,
          surface: c.bgBase,
          onSurface: c.text,
          onSurfaceVariant: c.subtle,
          outline: c.subtle,
          surfaceContainerHigh: c.panel,
          surfaceContainerHighest: c.panel,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
    );
    final text = _textTheme(base.textTheme, c);
    final r16 = BorderRadius.circular(16);
    final overlayBg = isLight
        ? const Color(0xF2FFFFFF)
        : const Color(0xF21E2B45);
    const bold = TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700);
    const medium = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
    );

    return base.copyWith(
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: c.bgBase,
      iconTheme: IconThemeData(color: c.text),
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.heading,
        titleTextStyle: bold.copyWith(fontSize: 20, color: c.heading),
      ),
      cardTheme: CardThemeData(
        color: c.panel,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.panelEdge),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _glassButton(PqPalette.blueTone),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _glassButton(c.neutral),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: bold.copyWith(fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.panel,
        selectedColor: PqPalette.yellowTone.top,
        side: BorderSide(color: c.panelEdge),
        shape: const StadiumBorder(),
        labelStyle: medium.copyWith(color: c.text),
        secondaryLabelStyle: medium.copyWith(
          color: PqPalette.yellowTone.onColor,
        ),
        checkmarkColor: PqPalette.yellowTone.onColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.panel,
        labelStyle: TextStyle(color: c.subtle),
        prefixIconColor: c.subtle,
        suffixIconColor: c.subtle,
        border: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: c.panelEdge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: c.panelEdge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: const BorderSide(color: PqPalette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: const BorderSide(color: PqPalette.danger, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: PqPalette.blueTone.bottom,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Colors.white : c.subtle,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? bold.copyWith(fontSize: 11, color: c.heading)
              : medium.copyWith(fontSize: 11, color: c.subtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? const Color(0xFF424E66)
            : const Color(0xFF28385A),
        contentTextStyle: medium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: r16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: overlayBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.panelEdge),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: overlayBg,
        modalBackgroundColor: overlayBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: PqPalette.blue,
        linearTrackColor: c.panel,
        circularTrackColor: Colors.transparent,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? PqPalette.blueTone.bottom
                : c.panel,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : c.text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: c.panelEdge)),
          textStyle: WidgetStatePropertyAll(bold.copyWith(fontSize: 13)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.subtle,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? PqPalette.blue : c.panel,
        ),
        trackOutlineColor: WidgetStatePropertyAll(c.panelEdge),
      ),
      listTileTheme: ListTileThemeData(textColor: c.text, iconColor: c.subtle),
      dividerTheme: DividerThemeData(color: c.subtle.withValues(alpha: 0.25)),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: c.subtle,
        indicatorColor: scheme.primary,
        dividerColor: Colors.transparent,
        labelStyle: bold.copyWith(fontSize: 14),
        unselectedLabelStyle: medium.copyWith(fontSize: 14),
      ),
    );
  }

  /// Judul 700 warna heading, isi 500 warna teks; tidak ada bobot 800 atau lebih.
  static TextTheme _textTheme(TextTheme t, PqColors c) {
    TextStyle? head(TextStyle? s) =>
        s?.copyWith(fontWeight: FontWeight.w700, color: c.heading);
    TextStyle? body(TextStyle? s) =>
        s?.copyWith(fontWeight: FontWeight.w500, color: c.text);
    return t.copyWith(
      displayLarge: head(t.displayLarge),
      displayMedium: head(t.displayMedium),
      displaySmall: head(t.displaySmall),
      headlineLarge: head(t.headlineLarge),
      headlineMedium: head(t.headlineMedium),
      headlineSmall: head(t.headlineSmall),
      titleLarge: head(t.titleLarge),
      titleMedium: head(t.titleMedium),
      titleSmall: head(t.titleSmall),
      bodyLarge: body(t.bodyLarge),
      bodyMedium: body(t.bodyMedium),
      bodySmall: body(t.bodySmall)?.copyWith(color: c.subtle),
      labelLarge: t.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: c.text,
      ),
      labelMedium: body(t.labelMedium),
      labelSmall: body(t.labelSmall)?.copyWith(color: c.subtle),
    );
  }

  /// Tombol kaca 3D lewat backgroundBuilder: Material dibuat transparan,
  /// lalu GlassSurface menggambar kaca dan menggeser konten saat ditekan.
  static ButtonStyle _glassButton(GlassToneColors tone) => ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    side: const WidgetStatePropertyAll(BorderSide.none),
    splashFactory: NoSplash.splashFactory,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? tone.onColor.withValues(alpha: 0.6)
          : tone.onColor,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? tone.onColor.withValues(alpha: 0.6)
          : tone.onColor,
    ),
    backgroundBuilder: (context, states, child) => GlassSurface(
      tone: tone,
      pressed: states.contains(WidgetState.pressed),
      dimmed: states.contains(WidgetState.disabled),
      haptic: true,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
