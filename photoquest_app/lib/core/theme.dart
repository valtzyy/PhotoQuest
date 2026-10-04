import 'package:flutter/material.dart';

/// Tema Material 3 dengan satu warna utama: oranye "golden hour".
class AppTheme {
  AppTheme._();

  static const Color goldenOrange = Color(0xFFF2994A);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: goldenOrange),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: goldenOrange,
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      );
}
