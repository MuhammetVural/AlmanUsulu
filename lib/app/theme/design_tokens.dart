// design_tokens.dart
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final double radiusS, radiusM, radiusL;
  final EdgeInsets fieldPadding;
  final double dividerThin;
  final double avatarSize;
  final List<BoxShadow> softShadow;

  const AppTokens({
    this.radiusS = 8,
    this.radiusM = 14,
    this.radiusL = 28,
    this.fieldPadding = const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    this.dividerThin = .5,
    this.avatarSize = 44,
    this.softShadow = const [BoxShadow(blurRadius: 18, offset: Offset(0, 10), spreadRadius: -2, color: Colors.black12)],
  });

  @override
  AppTokens copyWith({double? radiusS,double? radiusM,double? radiusL,EdgeInsets? fieldPadding,double? dividerThin,double? avatarSize,List<BoxShadow>? softShadow}) =>
      AppTokens(
        radiusS: radiusS ?? this.radiusS,
        radiusM: radiusM ?? this.radiusM,
        radiusL: radiusL ?? this.radiusL,
        fieldPadding: fieldPadding ?? this.fieldPadding,
        dividerThin: dividerThin ?? this.dividerThin,
        avatarSize: avatarSize ?? this.avatarSize,
        softShadow: softShadow ?? this.softShadow,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      radiusS: lerpDouble(radiusS, other.radiusS, t)!,
      radiusM: lerpDouble(radiusM, other.radiusM, t)!,
      radiusL: lerpDouble(radiusL, other.radiusL, t)!,
      fieldPadding: EdgeInsets.lerp(fieldPadding, other.fieldPadding, t)!,
      dividerThin: lerpDouble(dividerThin, other.dividerThin, t)!,
      avatarSize: lerpDouble(avatarSize, other.avatarSize, t)!,
      softShadow: other.softShadow,
    );
  }
}