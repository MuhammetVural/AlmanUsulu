import 'package:sqflite/sqflite.dart';
import '../../data/db/database_provider.dart';

class GroupRepo {
  final Future<Database> _db = AppDatabase.instance.db;

  Future<int> createGroup(String name) async {
    final db = await _db;
    return db.insert('groups', {
      'name': name.trim(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> listGroups() async {
    final db = await _db;
    return db.query('groups', orderBy: 'created_at DESC');
  }

  Future<int> deleteGroup(int id) async {
    final db = await _db;
    return db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }
}