import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class RolePill extends StatelessWidget {
  const RolePill({super.key, required this.labelKey, required this.color});
  final String labelKey; // owner | admin | member
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (labelKey.isEmpty) return const SizedBox.shrink();
    final bg = color.withValues(alpha: .12);
    final fg = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'group.role.$labelKey'.tr(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
      ),
    );
  }
}