import 'package:flutter/material.dart';

class SoftSquareAvatar extends StatelessWidget {
  const SoftSquareAvatar({
    super.key,
    required this.size,
    required this.child,
    this.radius = 14,
  });

  final double size;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface; // açık tema: beyaza yakın, karanlıkta koyu
    final shadowColor = scheme.shadow.withOpacity(
      Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.12,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          // gölge: yumuşak ve aşağı doğru
          BoxShadow(blurRadius: 18, offset: Offset(0, 10), spreadRadius: -2),
        ].map((b) => b.copyWith(color: shadowColor)).toList(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Center(child: child),
      ),
    );
  }
}