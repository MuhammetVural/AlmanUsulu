import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/providers.dart';
import '../../../../core/ui/notifications.dart';
import '../../../../utils/string_utils.dart';
import 'soft_square_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class ExpenseTile extends StatelessWidget {
  final Map<String, dynamic> expense;
  final List<Map<String, dynamic>> members;
  final int groupId;
  final WidgetRef ref;
  final bool canManage;
  const ExpenseTile({required this.expense, required this.members, required this.groupId, required this.ref, this.canManage = false, super.key});

  @override
  Widget build(BuildContext context) {
    final ts = DateTime.fromMillisecondsSinceEpoch((expense['created_at'] as int) * 1000).toLocal();
    final dateStr = DateFormat('dd-MM-yyyy | HH:mm').format(ts);
    final amountText = (expense['amount'] as num).toStringAsFixed(2);
    final payerId = expense['payer_id'] as int;
    final payerName = (members.firstWhere(
          (m) => m['id'] == payerId,
      orElse: () => {'name': 'Üye #$payerId'},
    )['name'] as String);


    return ListTile(
      leading: SoftSquareAvatar(size: 44, child: Text(
        payerName.isNotEmpty ? payerName.trim()[0].toUpperCase() : '•',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),),
      title: Text(
        capitalizeTr(expense['title']?.toString() ?? '(Başlıksız)'),
      ),
      subtitle: Text('${capitalizeTr(payerName)} • $dateStr'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+$amountText₺',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canManage) // 👈 sadece owner/admin görür
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Silinsin mi?'),
                    content: const Text('Bu harcama silinecek, emin misiniz?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(expenseRepoProvider).softDeleteExpense(expense['id'] as int);
                  ref.invalidate(expensesProvider(groupId));
                  ref.invalidate(filteredExpensesProvider);
                  ref.invalidate(visibleExpensesProvider(groupId));
                  ref.invalidate(balancesProvider(groupId));
                  if (context.mounted) {
                    showAppSnack(
                      ref,
                      title: 'common.success'.tr(),
                      message: 'Harcama silindi',
                      type: AppNotice.success,
                    );
                  }
                }
              },
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}