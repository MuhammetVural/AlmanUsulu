import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteGroupRepo {
  RemoteGroupRepo(this.client);
  final SupabaseClient client;

  Future<int> createGroup(String name) async {
    final res = await client.from('groups').insert({
      'name': name,
    }).select('id').single();
    return (res['id'] as int);
  }

  Future<void> updateGroupName(int id, String newName) async {
    await client.from('groups')
        .update({'name': newName})
        .eq('id', id);
  }

  Future<void> softDeleteGroup(int id) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await client.from('groups')
        .update({'deleted_at': nowSec})
        .eq('id', id);
  }

  Future<void> undoDeleteGroup(int id) async {
    await client.from('groups')
        .update({'deleted_at': null})
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listGroups() async {
    final rows = await client
        .from('groups')
        .select('*')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}