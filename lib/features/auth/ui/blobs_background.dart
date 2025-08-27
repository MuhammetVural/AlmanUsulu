// lib/features/auth/ui/blobs_background.dart
import 'package:flutter/material.dart';

class BlobsBackground extends StatelessWidget {
  const BlobsBackground({
    super.key,
    required this.topRightColor,
    required this.bottomLeftColor,
  });

  final Color topRightColor;
  final Color bottomLeftColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // sağ üst büyük daire
          Positioned(
            right: -80,
            top: -40,
            child: _Blob(color: topRightColor, size: 280),
          ),
          // sol orta büyük daire
          Positioned(
            left: -60,
            top: 180,
            child: _Blob(color: bottomLeftColor.withOpacity(0.85), size: 260),
          ),
          // sağ alt büyük daire (login’de belirgin)
          Positioned(
            right: -120,
            bottom: -60,
            child: _Blob(color: bottomLeftColor, size: 360),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
