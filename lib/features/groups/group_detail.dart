import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class GroupDetailPage extends ConsumerWidget {
  final int groupId;
  final String groupName;
  const GroupDetailPage({super.key, required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider(groupId));
    final expensesAsync = ref.watch(expensesProvider(groupId));
    final balancesAsync = ref.watch(balancesProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: Text(groupName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(membersProvider(groupId));
          ref.invalidate(expensesProvider(groupId));
          ref.invalidate(balancesProvider(groupId));
        },
        child: ListView(
          children: [
            const ListTile(title: Text('Bakiye Özeti')),
            balancesAsync.when(
              data: (bals) {
                if (bals.isEmpty) {
                  return const ListTile(title: Text('Üye yok'));
                }
                return Column(
                  children: bals.entries.map((e) {
                    final member = (membersAsync.asData?.value ?? []).firstWhere(
                          (m) => m['id'] == e.key,
                      orElse: () => {'name': 'Üye #${e.key}'},
                    );
                    final amount = e.value;
                    final sign = amount >= 0 ? '+' : '';
                    return ListTile(
                      dense: true,
                      title: Text(member['name'] as String),
                      trailing: Text('$sign${amount.toStringAsFixed(2)}'),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error: (e, _) => ListTile(title: Text('Bakiye hatası: $e')),
            ),
            const Divider(),
            const ListTile(title: Text('Harcamalar')),
            expensesAsync.when(
              data: (rows) => rows.isEmpty
                  ? const ListTile(title: Text('Henüz harcama yok'))
                  : Column(
                children: rows.map((e) {
                  final ts = DateTime.fromMillisecondsSinceEpoch(e['created_at'] as int);
                  return ListTile(
                    title: Text(e['title']?.toString() ?? '(Başlıksız)'),
                    subtitle: Text('${ts.toLocal()}'),
                    trailing: Text((e['amount'] as num).toStringAsFixed(2)),
                  );
                }).toList(),
              ),
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error: (e, _) => ListTile(title: Text('Harcama hatası: $e')),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: _Fab(groupId: groupId),
    );
  }
}

class _Fab extends ConsumerWidget {
  final int groupId;
  const _Fab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (key) async {
        if (key == 'member') {
          final name = await _askText(context, 'Üye adı');
          if (name != null && name.trim().isNotEmpty) {
            await ref.read(memberRepoProvider).addMember(groupId, name.trim());
            ref.invalidate(membersProvider(groupId));
            ref.invalidate(balancesProvider(groupId));
          }
        } else if (key == 'expense') {
          await _addExpenseFlow(context, ref, groupId);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'member', child: Text('Üye ekle')),
        PopupMenuItem(value: 'expense', child: Text('Harcama ekle')),
      ],
      child: const FloatingActionButton(child: Icon(Icons.add), onPressed: null),
    );
  }

  Future<void> _addExpenseFlow(BuildContext context, WidgetRef ref, int groupId) async {
    final members = await ref.read(memberRepoProvider).listMembers(groupId);
    if (members.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce en az bir üye ekleyin.')));
      }
      return;
    }
    final title = await _askText(context, 'Harcama başlığı (opsiyonel)');
    if (title == null) return;

    final amountStr = await _askText(context, 'Tutar (ör. 120.50)');
    if (amountStr == null) return;
    final amount = double.tryParse(amountStr.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçersiz tutar.')));
      }
      return;
    }

    // Payer seçimi
    final payerId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ödeyen'),
        children: members
            .map((m) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, m['id'] as int),
          child: Text(m['name'] as String),
        ))
            .toList(),
      ),
    );
    if (payerId == null) return;

    // Katılımcılar (hepsi eşit bölüşüm, v1)
    final participantIds = members.map<int>((m) => m['id'] as int).toList();

    await ref.read(expenseRepoProvider).addExpense(
      groupId: groupId,
      title: title,
      amount: amount,
      payerId: payerId,
      participantIds: participantIds,
    );
    ref.invalidate(expensesProvider(groupId));
    ref.invalidate(balancesProvider(groupId));
  }

  Future<String?> _askText(BuildContext context, String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Tamam')),
        ],
      ),
    );
  }
}