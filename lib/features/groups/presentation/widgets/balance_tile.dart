import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utils/string_utils.dart';

class BalanceTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final double amount;
  final List<Map<String, dynamic>> members;
  final int groupId;
  final WidgetRef ref;
  const BalanceTile({required this.member, required this.amount, required this.members, required this.groupId, required this.ref, super.key});

  @override
  Widget build(BuildContext context) {
    final sign = amount >= 0 ? '+' : '';
    final isSelf = (member['user_id'] == Supabase.instance.client.auth.currentUser?.id);
    return ListTile(
      dense: true,
      title: Text(capitalizeTr(member['name'] as String)),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: colorFromString(member['id'].toString() + (member['name'] as String? ?? '')),
        child: Text(
          (member['name'] as String).isNotEmpty
              ? (member['name'] as String)[0].toUpperCase()
              : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      trailing: Text(
        (amount >= 0)
            ? '+${amount.abs().toStringAsFixed(2)}₺'
            : '-${amount.abs().toStringAsFixed(2)}₺',
        style: TextStyle(
          color: amount >= 0 ? Colors.green : Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
      // İstersen burada popup menu vs. ekleyebilirsin
      subtitle: isSelf ? const Text('Sen', style: TextStyle(fontSize: 12)) : null,
    );
  }
}