import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/db/database_provider.dart';

class GroupRepo {
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> createGroup(String name) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw PostgrestException(
        message: 'AUTH_REQUIRED: Grup oluşturmak için giriş yapmalısınız.',
        code: '401',
        details: 'Unauthorized',
        hint: null,
      );
    }

    // 1) Grubu owner_id ile oluştur (RLS: grp_ins -> owner_id = auth.uid())
    final inserted = await _client
        .from('groups')
        .insert({
      'name': name.trim(),
      'owner_id': uid,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    })
        .select('id')
        .single();

    final groupId = (inserted['id'] as num).toInt();
    return groupId;
  }

  Future<List<Map<String, dynamic>>> listGroups() async {
    final rows = await _client
        .from('groups')
        .select('*')
        .isFilter('deleted_at', null) // SDK’na göre .is_('deleted_at', null) da olabilir
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<int> deleteGroup(int id) async {
    final deleted = await _client
        .from('groups')
        .delete()
        .eq('id', id)
        .select('id');        // silinen satırları döndür
    return (deleted as List).isNotEmpty ? 1 : 0;
  }

  // DB'de soft delete (deleted_at kolonunu doldurur)
  Future<void> softDeleteGroup(int id) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _client.from('groups').update({'deleted_at': nowSec}).eq('id', id);
  }
  Future<void> updateGroupName(int id, String name) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _client
        .from('groups')
        .update({'name': name.trim(), 'updated_at': nowSec})
        .eq('id', id);
  }

// Soft delete geri al (deleted_at kolonunu null yapar)
  Future<void> undoDeleteGroup(int id) async {
    await _client.from('groups').update({'deleted_at': null}).eq('id', id);
  }
}