// lib/utils/string_utils.dart
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