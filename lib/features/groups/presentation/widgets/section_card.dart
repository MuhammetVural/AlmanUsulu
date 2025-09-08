import 'package:flutter/material.dart';
import '../../../../app/theme/theme_utils.dart';
import 'faded_divider.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.header,
    this.brandTint,
  });

  final String title;
  final List<Widget> children;
  final Widget? header;
  final Color? brandTint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // ⬇️ Sorduğun satırlar tam burada kullanılacak
    final bg = brandTint != null
        ? adaptSoftForTheme(brandTint!, context)
        : cs.surfaceContainerHighest;

    final border = (brandTint ?? cs.outlineVariant).withOpacity(.35);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header ??
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
            const SizedBox(height: 8),
            const Divider(thickness: 0.5, height: 0.5),
            const SizedBox(height: 2),
            ..._intersperseWithFadedDividers(children),
          ],
        ),
      ),
    );
  }
}

List<Widget> _intersperseWithFadedDividers(List<Widget> items) {
  if (items.isEmpty) return items;
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    out.add(items[i]);
    if (i != items.length - 1) out.add(const FadedDivider());
  }
  return out;
}