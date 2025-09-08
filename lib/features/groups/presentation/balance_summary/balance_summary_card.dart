import 'package:flutter/material.dart';
import '../../../../app/theme/theme_utils.dart';

class BalanceSummaryCard extends StatelessWidget {
  const BalanceSummaryCard({
    super.key,
    required this.items,
    this.onSeeAll,
    this.brandTint,
    this.title,
    this.subtitle,
  });

  final List<Widget> items;
  final VoidCallback? onSeeAll;
  final Color? brandTint;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = brandTint != null
        ? adaptSoftForTheme(brandTint!, context)
        : cs.surfaceContainerHigh;
    final border = (brandTint ?? cs.outlineVariant).withOpacity(.35);
    final patternColor = (brandTint ?? cs.primary)
        .withOpacity(theme.brightness == Brightness.dark ? .05 : .08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
          image: const DecorationImage(
            image: AssetImage('assets/patterns/doodle3.png'),
            repeat: ImageRepeat.repeat,
            fit: BoxFit.none,
            opacity: 1.0,
          ),
        ),
        // pattern’ı brandTint ile tonla
        foregroundDecoration: BoxDecoration(
          color: patternColor,
          backgroundBlendMode: BlendMode.srcATop,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || subtitle != null) ...[
              Text(
                title ?? '',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(.7),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: items),
            if (onSeeAll != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSeeAll,
                  child: const Text('Filtrele'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}