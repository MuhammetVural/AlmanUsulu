import 'package:flutter/material.dart';
import 'design_tokens.dart';

ThemeData lightTheme() {
  final seed = const Color(0xFF0E9F6E);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,

    // Global TextField default’ları (gerekirse)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface, // light yüzey
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    ),

    extensions: const [
      AppTokens(
        radiusL: 28.0,
        fieldPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    ],
  );
}

ThemeData darkTheme() {
  final seed = const Color(0xFF0A7A53);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest, // dark’ta biraz daha koyu yüzey
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    ),
    extensions: const [
      AppTokens(
        radiusL: 28.0,
        fieldPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    ],
  );
}
