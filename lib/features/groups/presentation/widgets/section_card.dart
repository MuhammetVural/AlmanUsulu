import 'package:flutter/material.dart';
import 'faded_divider.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.header,
  });

  final String title;
  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
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