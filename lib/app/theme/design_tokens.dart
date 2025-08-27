import 'dart:ui';

import 'package:flutter/material.dart';

/// Uygulamaya özel tasarım değişkenleri
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.radiusL,
    required this.fieldPadding,
  });

  /// Oval köşe yarıçapı (textfield, buton vs.)
  final double radiusL;

  /// TextField iç dolgusu
  final EdgeInsets fieldPadding;

  @override
  AppTokens copyWith({double? radiusL, EdgeInsets? fieldPadding}) {
    return AppTokens(
      radiusL: radiusL ?? this.radiusL,
      fieldPadding: fieldPadding ?? this.fieldPadding,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      radiusL: lerpDouble(radiusL, other.radiusL, t)!,
      fieldPadding: EdgeInsets.lerp(fieldPadding, other.fieldPadding, t)!,
    );
  }

  static AppTokens of(BuildContext ctx) =>
      Theme.of(ctx).extension<AppTokens>()!;
}
