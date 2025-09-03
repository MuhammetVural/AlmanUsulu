import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';

Future<void> openExpenseFilterSheet(
    BuildContext context,
    WidgetRef ref,
    int groupId,
    List<Map<String, dynamic>> members,
    ) async {
  final current = ref.read(currentExpenseFilterProvider(groupId));
  int? selPayerId = current?.payerId;
  DateTime? selFrom = current?.fromSec == null ? null : DateTime.fromMillisecondsSinceEpoch(current!.fromSec! * 1000).toLocal();
  DateTime? selTo = current?.toSec == null ? null : DateTime.fromMillisecondsSinceEpoch(current!.toSec! * 1000).toLocal();

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final hasSelection = selPayerId != null || selFrom != null || selTo != null;

          String payerLabel() {
            if (selPayerId == null) return 'Hepsi';
            final m = members.firstWhere((x) => (x['id'] as num).toInt() == selPayerId, orElse: () => {'name': 'Üye #$selPayerId'});
            return (m['name']?.toString() ?? 'Üye #$selPayerId');
          }

          String dateLabel() {
            if (selFrom == null && selTo == null) return 'Tümü';
            String f(DateTime d) => DateFormat('dd.MM.yyyy').format(d);
            if (selFrom != null && selTo != null) return '${f(selFrom!)} → ${f(selTo!)}';
            if (selFrom != null) return '${f(selFrom!)} → ∞';
            return '−∞ → ${f(selTo!)}';
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Harcamaları Filtrele',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Divider(height: 0.5),
                  const SizedBox(height: 4),

                  // Ödeyen
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Ödeyen'),
                    subtitle: Text(payerLabel()),
                    onTap: () async {
                      final id = await showDialog<int>(
                        context: ctx,
                        builder: (dctx) => SimpleDialog(
                          title: const Text('Ödeyen seç'),
                          children: [
                            SimpleDialogOption(onPressed: () => Navigator.pop(dctx, null), child: const Text('Hepsi')),
                            ...members.map((m) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(dctx, (m['id'] as num).toInt()),
                              child: Text(m['name']?.toString() ?? 'Üye'),
                            )),
                          ],
                        ),
                      );
                      setState(() => selPayerId = id);
                    },
                  ),

                  // Tarih aralığı
                  ListTile(
                    leading: const Icon(Icons.date_range),
                    title: const Text('Tarih Aralığı'),
                    subtitle: Text(dateLabel()),
                    onTap: () async {
                      final now = DateTime.now();
                      final initialStart = selFrom ?? now.subtract(const Duration(days: 30));
                      final initialEnd = selTo ?? now;
                      final picked = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(now.year + 2),
                        initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
                        currentDate: now,
                        helpText: 'Tarih aralığı seç',
                      );
                      if (picked != null) {
                        setState(() {
                          selFrom = picked.start;
                          selTo = picked.end;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: hasSelection
                            ? () {
                          setState(() {
                            selPayerId = null;
                            selFrom = null;
                            selTo = null;
                          });
                        }
                            : null,
                        icon: const Icon(Icons.clear),
                        label: const Text('Temizle'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          if (selPayerId == null && selFrom == null && selTo == null) {
                            clearExpenseFilter(ref, groupId);
                          } else {
                            setExpenseFilter(ref, groupId, payerId: selPayerId, from: selFrom, to: selTo);
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text('Uygula'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}