import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteExpenseRepo {
  RemoteExpenseRepo(this.client);
  final SupabaseClient client;

  Future<int> addExpense({
    required int groupId,
    required String title,
    required double amount,
    required int payerId,
    required List<int> participantIds,
  }) async {
    // 1) expense insert
    final exp = await client.from('expenses').insert({
      'group_id': groupId,
      'title': (title.trim().isEmpty ? null : title.trim()),
      'amount': amount,
      'payer_id': payerId,
    }).select('id').single();
    final expenseId = exp['id'] as int;

    // 2) participants batch insert
    final rows = participantIds
        .map((mid) => {'expense_id': expenseId, 'member_id': mid})
        .toList();
    if (rows.isNotEmpty) {
      await client.from('expense_participants').insert(rows);
    }
    return expenseId;
  }

  Future<void> softDeleteExpense(int expenseId) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await client.from('expenses')
        .update({'deleted_at': nowSec})
        .eq('id', expenseId);
  }

  Future<void> undoDeleteExpense(int id) async {
    await client.from('expenses').update({'deleted_at': null}).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listExpenses(int groupId) async {
    final rows = await client
        .from('expenses')
        .select('*')
        .eq('group_id', groupId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listParticipants(int expenseId) async {
    final rows = await client
        .from('expense_participants')
        .select('*')
        .eq('expense_id', expenseId)
        .isFilter('deleted_at', null);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> updateExpenseTitle(int expenseId, String? title) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await client.from('expenses').update({
      'title': title,
      'updated_at': nowSec,
    }).eq('id', expenseId).isFilter('deleted_at', null);
  }

  Future<void> updateExpense(int id, {required String title, required double amount}) async {
    await client.from('expenses')
        .update({'title': title, 'amount': amount})
        .eq('id', id);
  }

  Future<bool> hasActiveExpenses(int groupId) async {
    final rows = await client
        .from('expenses')
        .select('id' )
        .eq('group_id', groupId)
        .isFilter('deleted_at', null)
        .limit(1);
    return rows.isNotEmpty;
  }
  // RemoteExpenseRepo içine ekleyin:
  Future<Map<int, double>> getEventBalances(int groupId) async {
    final rows = await client.rpc(
      'get_event_balances',
      params: {'p_group_id': groupId},
    );
    final map = <int, double>{};
    for (final r in rows) {
      map[(r['member_id'] as num).toInt()] = (r['balance'] as num).toDouble();
    }
    return map;
  }
}