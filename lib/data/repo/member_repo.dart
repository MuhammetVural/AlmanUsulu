import 'package:sqflite/sqflite.dart';
import '../../data/db/database_provider.dart';

class MemberRepo {
  final Future<Database> _db = AppDatabase.instance.db;

  // MemberRepo içinde
  Future<int> addMember(int groupId, String name) async {
    final db = await _db;
    return db.insert('members', {
      'group_id': groupId,
      'name': name.trim(),
      'is_active': 1,
    });
  }

  Future<List<Map<String, dynamic>>> listMembers(int groupId) async {
    final db = await _db;
    return db.query('members', where: 'group_id = ? AND deleted_at IS NULL', whereArgs: [groupId], orderBy: 'id DESC');
  }

  Future<int> deleteMember(int id) async {
    final db = await _db;
    return db.delete('members', where: 'id = ?', whereArgs: [id]);
  }
  // Üyeyi sil: members.deleted_at = now
// + Bu üyenin, bu gruptaki TÜM AKTİF harcamalardaki katılımını pasifleştir (expense_participants.deleted_at = now)
  Future<void> softDeleteMember(int groupId, int memberId) async {
    final db = await _db; // kendi erişimin
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.transaction((txn) async {
      // 1) Üyenin kendisini soft-delete
      await txn.update(
        'members',
        {'deleted_at': nowSec, 'is_active': 0, 'updated_at': nowSec},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [memberId],
      );

      // 2) Bu gruptaki AKTİF harcamalarda katılımını pasifleştir
      await txn.rawUpdate('''
      UPDATE expense_participants
         SET deleted_at = ?
       WHERE member_id = ?
         AND deleted_at IS NULL
         AND expense_id IN (
              SELECT id FROM expenses
               WHERE group_id = ? AND deleted_at IS NULL
         )
    ''', [nowSec, memberId, groupId]);
    });
  }
  // Üyeyi geri al: members.deleted_at = NULL, is_active = 1
// + Bu üyenin, bu gruptaki AKTİF harcamalardaki katılımını da geri getir (expense_participants.deleted_at = NULL)
  Future<void> undoDeleteMember(int groupId, int memberId) async {
    final db = await _db;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.transaction((txn) async {
      // 1) Üyeyi geri al
      await txn.update(
        'members',
        {'deleted_at': null, 'is_active': 1, 'updated_at': nowSec},
        where: 'id = ? AND deleted_at IS NOT NULL',
        whereArgs: [memberId],
      );

      // 2) Bu gruptaki AKTİF harcamalarda katılımını geri getir
      await txn.rawUpdate('''
      UPDATE expense_participants
         SET deleted_at = NULL
       WHERE member_id = ?
         AND deleted_at IS NOT NULL
         AND expense_id IN (
              SELECT id FROM expenses
               WHERE group_id = ? AND deleted_at IS NULL
         )
    ''', [memberId, groupId]);
    });
  }

  Future<void> updateMemberName(int memberId, String name) async {
    final db = await _db; // senin MemberRepo’daki DB erişimin
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      'members',
      {'name': name.trim(), 'updated_at': nowSec},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [memberId],
    );
  }
  Future<void> includeMemberInPastExpenses(int groupId, int memberId) async {
    final db = await _db;

    // Grup içindeki tüm harcamaları bul
    final expenses = await db.query(
      'expenses',
      where: 'group_id = ? AND deleted_at IS NULL',
      whereArgs: [groupId],
    );

    for (final expense in expenses) {
      final expenseId = expense['id'] as int;

      // Daha önce bu harcamada var mı kontrol et
      final existing = await db.query(
        'expense_participants',
        where: 'expense_id = ? AND member_id = ?',
        whereArgs: [expenseId, memberId],
      );

      if (existing.isEmpty) {
        await db.insert('expense_participants', {
          'expense_id': expenseId,
          'member_id': memberId,
        });
      }
    }
  }
  Future<void> includeMemberInPastExpensesFast(int groupId, int memberId) async {
    final db = await _db;

    await db.transaction((txn) async {
      // 1) Soft-deleted kayıtları canlandır
      await txn.rawUpdate('''
      UPDATE expense_participants
         SET deleted_at = NULL
       WHERE member_id = ?
         AND deleted_at IS NOT NULL
         AND expense_id IN (
              SELECT id FROM expenses
               WHERE group_id = ? AND deleted_at IS NULL
         )
    ''', [memberId, groupId]);

      // 2) Eksik olanları ekle
      await txn.rawInsert('''
      INSERT INTO expense_participants (expense_id, member_id)
      SELECT e.id, ?
        FROM expenses e
       WHERE e.group_id = ? AND e.deleted_at IS NULL
         AND NOT EXISTS (
               SELECT 1 FROM expense_participants p
                WHERE p.expense_id = e.id
                  AND p.member_id = ?
                  AND p.deleted_at IS NULL
         )
    ''', [memberId, groupId, memberId]);
    });
  }
}