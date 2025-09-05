import 'package:flutter/material.dart';

/// 10 parçalı pastel palet
const List<Color> kSoftPalette = [
  Color(0xFFEDEBFF), Color(0xFFE7F3FF), Color(0xFFFFEEF2), Color(0xFFFFF3E5),
  Color(0xFFEFFBF1), Color(0xFFEAF7FF), Color(0xFFFFF0F5), Color(0xFFEFF0FF),
  Color(0xFFEFFAF6), Color(0xFFFFFAE5),
];

Color softFromSeed(String seed) {
  final h = seed.hashCode.abs();
  return kSoftPalette[h % kSoftPalette.length];
}

/// listedeki her grup için renk atar:
List<Color> assignSoftColors(List<String> names) {
  final int n = kSoftPalette.length;
  final used = <int>{};
  final colors = <Color>[];
  int? prevIdx;

  for (final seed in names) {
    final base = seed.hashCode.abs() % n;
    int pick = -1;

    for (int step = 0; step < n; step++) {
      final idx = (base + step) % n;
      if (!used.contains(idx) && idx != prevIdx) {
        pick = idx;
        break;
      }
    }
    if (pick == -1) {
      for (int step = 0; step < n; step++) {
        final idx = (base + step) % n;
        if (idx != prevIdx) {
          pick = idx;
          break;
        }
      }
    }

    used.add(pick);
    prevIdx = pick;
    colors.add(kSoftPalette[pick]);
  }
  return colors;
}

/// Koyu temada yumuşat; açıkta aynen
Color adaptSoftForTheme(Color base, BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (!isDark) return base;

  final h = HSLColor.fromColor(base);
  final toned = h
      .withSaturation((h.saturation * 0.55).clamp(0.0, 1.0))
      .withLightness((h.lightness * 0.45).clamp(0.0, 1.0))
      .toColor();

  return Color.alphaBlend(toned.withOpacity(0.65), cs.surface);
}

/// Desen opaklığı: koyuda düşür, açıkta artır
double patternOpacity(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? 0.05 : 0.12;
}