import 'package:supabase_flutter/supabase_flutter.dart';

class MemberRepo {
  final SupabaseClient _client = Supabase.instance.client;

  // MemberRepo içinde
  Future<int> addMember(int groupId, String name) async {
    final n = name.trim();
    final inserted = await _client.from('members').insert({
      'group_id': groupId,
      'name': n.isEmpty ? 'İsimsiz' : n,
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    })
        .select('id')
        .single();
    return (inserted['id'] as num).toInt();
  }

  Future<void> leaveGroup(int groupId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw PostgrestException(
        message: 'AUTH_REQUIRED: Gruptan ayrılmak için giriş yapmalısınız.',
        code: '401',
        details: 'Unauthorized',
        hint: null,
      );
    }

    // Bu kullanıcının bu gruptaki member id'sini bul
    final rows = await _client
        .from('members')
        .select('id')
        .eq('group_id', groupId)
        .eq('user_id', uid)
        .isFilter('deleted_at', null)
        .limit(1);

    if (rows.isNotEmpty) {
      final mid = (rows.first['id'] as num).toInt();
      await softDeleteMember(groupId, mid);
    }
  }

  Future<List<Map<String, dynamic>>> listMembers(int groupId) async {
    final rows = await _client.from('members').select('*').eq('group_id', groupId).isFilter('deleted_at', null).order('id', ascending: false);
    return List<Map<String, dynamic>>.from(rows);

  }

  Future<int> deleteMember(int id) async {
    final res = await _client.from('members').delete().eq('id', id);
    return res.count ?? 0;
  }
  // Üyeyi sil: members.deleted_at = now
// + Bu üyenin, bu gruptaki TÜM AKTİF harcamalardaki katılımını pasifleştir (expense_participants.deleted_at = now)
  Future<void> softDeleteMember(int groupId, int memberId) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Transaction yok → iki ayrı update yapıyoruz
    await _client
        .from('members')
        .update({'deleted_at': nowSec, 'is_active': 0, 'updated_at': nowSec})
        .eq('id', memberId);

    await _client
        .from('expense_participants')
        .update({'deleted_at': nowSec})
        .eq('member_id', memberId)
        .inFilter(
      'expense_id',
      (await _client
          .from('expenses')
          .select('id')
          .eq('group_id', groupId)
          .isFilter('deleted_at', null)) // aktif harcamalar
          .map((e) => e['id'])
          .toList(),
    );
  }
  // Üyeyi geri al: members.deleted_at = NULL, is_active = 1
// + Bu üyenin, bu gruptaki AKTİF harcamalardaki katılımını da geri getir (expense_participants.deleted_at = NULL)
  Future<void> undoDeleteMember(int groupId, int memberId) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _client
        .from('members')
        .update({'deleted_at': null, 'is_active': 1, 'updated_at': nowSec})
        .eq('id', memberId);

    await _client
        .from('expense_participants')
        .update({'deleted_at': null})
        .eq('member_id', memberId)
        .inFilter(
      'expense_id',
      (await _client
          .from('expenses')
          .select('id')
          .eq('group_id', groupId)
          .isFilter('deleted_at', null))
          .map((e) => e['id'])
          .toList(),
    );
  }

  Future<void> updateMemberName(int memberId, String name) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _client
        .from('members')
        .update({'name': name.trim(), 'updated_at': nowSec})
        .eq('id', memberId)
        .isFilter('deleted_at', null);
  }

  Future<void> updateMemberRole({
    required int groupId,
    required int memberId,
    required String role, // 'admin' | 'member'
  }) async {
    // Güvenlik: sadece aktif kaydı güncelle
    await _client
        .from('members')
        .update({'role': role, 'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000})
        .eq('id', memberId)
        .eq('group_id', groupId)
        .isFilter('deleted_at', null);
  }

  Future<void> includeMemberInPastExpenses(int groupId, int memberId) async {
    final expenses = await _client
        .from('expenses')
        .select('id')
        .eq('group_id', groupId)
        .isFilter('deleted_at', null);

    for (final expense in expenses) {
      final expenseId = expense['id'] as int;

      final existing = await _client
          .from('expense_participants')
          .select('id')
          .eq('expense_id', expenseId)
          .eq('member_id', memberId);

      if (existing.isEmpty) {
        await _client.from('expense_participants').insert({
          'expense_id': expenseId,
          'member_id': memberId,
        });
      }
    }
  }
  Future<void> includeMemberInPastExpensesFast(int groupId, int memberId) async {
    // 1) Soft-deleted kayıtları geri getir
    await _client
        .from('expense_participants')
        .update({'deleted_at': null})
        .eq('member_id', memberId)
        .inFilter(
      'expense_id',
      (await _client
          .from('expenses')
          .select('id')
          .eq('group_id', groupId)
          .isFilter('deleted_at', null))
          .map((e) => e['id'])
          .toList(),
    );

    // 2) Eksik olanları ekle (tek tek insert)
    final expenses = await _client
        .from('expenses')
        .select('id')
        .eq('group_id', groupId)
        .isFilter('deleted_at', null);

    for (final e in expenses) {
      final expenseId = e['id'] as int;

      final exists = await _client
          .from('expense_participants')
          .select('id')
          .eq('expense_id', expenseId)
          .eq('member_id', memberId)
          .isFilter('deleted_at', null);

      if (exists.isEmpty) {
        await _client.from('expense_participants').insert({
          'expense_id': expenseId,
          'member_id': memberId,
        });
      }
    }
  }
}