// lib/features/home/utils/soft_palette.dart (veya ortak utils)
import 'package:flutter/material.dart';

Color softFromSeed(String seed) {
  const palette = [
    Color(0xFFEDEBFF), Color(0xFFE7F3FF), Color(0xFFFFEEF2), Color(0xFFFFF3E5),
    Color(0xFFEFFBF1), Color(0xFFEAF7FF), Color(0xFFFFF0F5), Color(0xFFEFF0FF),
    Color(0xFFEFFAF6), Color(0xFFFFFAE5),
  ];
  final h = seed.hashCode.abs();
  return palette[h % palette.length];
}

Color adaptSoftForTheme(Color base, BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  if (!isDark) return base;
  final hsl = HSLColor.fromColor(base);
  final toned = hsl
      .withSaturation((hsl.saturation * 0.55).clamp(0, 1))
      .withLightness((hsl.lightness * 0.45).clamp(0, 1))
      .toColor();
  return Color.alphaBlend(toned.withOpacity(.65), cs.surface);
}