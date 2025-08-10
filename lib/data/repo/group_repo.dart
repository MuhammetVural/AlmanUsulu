import 'package:sqflite/sqflite.dart';
import '../../data/db/database_provider.dart';

class GroupRepo {
  final Future<Database> _db = AppDatabase.instance.db;

  Future<int> createGroup(String name) async {
    final db = await _db;
    return db.insert('groups', {
      'name': name.trim(),
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  Future<List<Map<String, dynamic>>> listGroups() async {
    final db = await _db;
    return db.query('groups', where: 'deleted_at IS NULL', orderBy: 'created_at DESC');
  }

  Future<int> deleteGroup(int id) async {
    final db = await _db;
    return db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // DB'de soft delete (deleted_at kolonunu doldurur)
  Future<void> softDeleteGroup(int id) async {
    final db = await _db;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      'groups',
      {'deleted_at': nowSec},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// Soft delete geri al (deleted_at kolonunu null yapar)
  Future<void> undoDeleteGroup(int id) async {
    final db = await _db;
    await db.update(
      'groups',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}