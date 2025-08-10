import 'package:sqflite/sqflite.dart';
import '../../data/db/database_provider.dart';

class MemberRepo {
  final Future<Database> _db = AppDatabase.instance.db;

  Future<int> addMember(int groupId, String name) async {
    final db = await _db;
    return db.insert('members', {'group_id': groupId, 'name': name.trim(), });
  }

  Future<List<Map<String, dynamic>>> listMembers(int groupId) async {
    final db = await _db;
    return db.query('members', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'id DESC');
  }

  Future<int> deleteMember(int id) async {
    final db = await _db;
    return db.delete('members', where: 'id = ?', whereArgs: [id]);
  }
  // MemberRepo içine
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
}