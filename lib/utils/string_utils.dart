// lib/utils/string_utils.dart
import 'dart:ui';

String capitalizeTr(String s) {
  if (s.isEmpty) return s;
  const trMap = {
    'i': 'İ', 'ı': 'I',
    'ğ': 'Ğ', 'ü': 'Ü',
    'ş': 'Ş', 'ö': 'Ö',
    'ç': 'Ç',
  };
  final first = s[0];
  final cap = trMap[first] ?? first.toUpperCase();
  return cap + s.substring(1);
}

String initialTr(String s, {String fallback = '•'}) {
  if (s.isEmpty) return fallback;
  const trMap = {
    'i': 'İ', 'ı': 'I',
    'ğ': 'Ğ', 'ü': 'Ü',
    'ş': 'Ş', 'ö': 'Ö',
    'ç': 'Ç',
  };
  final first = s.trim().isEmpty ? fallback : s.trim()[0];
  return trMap[first] ?? first.toUpperCase();
}

/// Deterministic (tutarlı) renk üretir. Avatarlar için uygundur.
/// Örn: colorFromString('${memberId}${memberName}')
 /// Helper function for generating a random color from a string (member id + name)
Color colorFromString(String input, {double opacity = 0.8}) {
  final hash = input.hashCode;
  final r = (hash & 0xFF0000) >> 16;
  final g = (hash & 0x00FF00) >> 8;
  final b = (hash & 0x0000FF);
  return Color.fromARGB(255, r, g, b).withOpacity(opacity);
}