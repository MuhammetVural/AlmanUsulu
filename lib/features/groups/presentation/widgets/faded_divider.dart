import 'package:flutter/material.dart';

class FadedDivider extends StatelessWidget {
  const FadedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final thickness = (1.0 / dpr).clamp(0.4, 1.0);
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Theme.of(context).colorScheme.outlineVariant.withOpacity(.35),
              Theme.of(context).colorScheme.outlineVariant.withOpacity(.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.15, 0.85, 1.0],
          ),
        ),
      ),
    );
  }
}