import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteMemberRepo {
  RemoteMemberRepo(this.client);
  final SupabaseClient client;

  Future<int> addMember(int groupId, String name) async {
    final res = await client.from('members').insert({
      'group_id': groupId,
      'name': name,
    }).select('id').single();
    return (res['id'] as int);
  }

  Future<void> updateMemberName(int memberId, String newName) async {
    await client.from('members').update({'name': newName}).eq('id', memberId);
  }

  Future<void> softDeleteMember(int groupId, int memberId) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await client.from('members')
        .update({'deleted_at': nowSec})
        .eq('id', memberId);
    // İsteğe bağlı: o üyenin expense_participants kayıtlarını da işaretlemek:
    await client.from('expense_participants')
        .update({'deleted_at': nowSec})
        .eq('member_id', memberId);
  }

  Future<void> undoDeleteMember(int memberId, int groupId) async {
    await client.from('members').update({'deleted_at': null}).eq('id', memberId);
    await client.from('expense_participants')
        .update({'deleted_at': null})
        .eq('member_id', memberId);
  }

  Future<List<Map<String, dynamic>>> listMembers(int groupId) async {
    final rows = await client
        .from('members')
        .select('*')
        .eq('group_id', groupId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}