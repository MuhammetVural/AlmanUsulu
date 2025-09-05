import 'package:flutter/material.dart';

class InlineAvatars extends StatelessWidget {
  const InlineAvatars({super.key, required this.members});
  final List<Map<String, dynamic>> members;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(3).toList();
    final width = (visible.length <= 1) ? 22.0 : (22.0 + (visible.length - 1) * 16.0);
    return SizedBox(
      width: width,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(visible.length, (i) {
          final m = visible[i];
          final name = (m['name'] as String?) ?? '';
          final initials = _initials(name);
          final bg = _avatarColorFor(name);
          return Positioned(
            left: i * 16.0,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              child: CircleAvatar(
                radius: 10,
                backgroundColor: bg,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return (parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString()).toUpperCase();
}

const List<Color> _kAvatarPalette = [
  Color(0xFF6C63FF), Color(0xFF2F88FF), Color(0xFFFF6B6B), Color(0xFFFF9E47),
  Color(0xFF00B894), Color(0xFF10B981), Color(0xFF6366F1), Color(0xFFEC4899),
  Color(0xFFF59E0B), Color(0xFF3B82F6), Color(0xFF14B8A6), Color(0xFF8B5CF6),
];

Color _avatarColorFor(String seed) {
  final h = seed.hashCode.abs();
  return _kAvatarPalette[h % _kAvatarPalette.length];
}