import 'package:flutter/material.dart';

/// Koyu temada yumuşatılmış pastel üretir; açık temada rengi aynen döner.
Color adaptSoftForTheme(Color base, BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (!isDark) return base;

  // HSL ile rengi sakinleştir (doygunluk ve aydınlık düşür)
  final h = HSLColor.fromColor(base);
  final toned = h
      .withSaturation((h.saturation * 0.55).clamp(0.0, 1.0))
      .withLightness((h.lightness * 0.45).clamp(0.0, 1.0))
      .toColor();

  // Yüzeyle harmanla (tema tutarlılığı)
  return Color.alphaBlend(toned.withOpacity(0.65), cs.surface);
}

/// Desen opaklığı: koyu temada daha düşük, açıkta biraz daha görünür.
double patternOpacity(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? 0.05 : 0.12;
}