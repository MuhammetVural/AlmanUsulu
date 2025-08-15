import 'package:sqflite/sqflite.dart';
import '../../data/db/database_provider.dart';

class ExpenseRepo {
  final Future<Database> _db = AppDatabase.instance.db;

  Future<int> addExpense({
    required int groupId,
    required String title,
    required double amount,
    required int payerId,
    required List<int> participantIds,
  }) async {
    final db = await _db;
    return await db.transaction((txn) async {
      final expenseId = await txn.insert('expenses', {
        'group_id': groupId,
        'title': title.trim().isEmpty ? null : title.trim(),
        'amount': amount,
        'payer_id': payerId,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      for (final mid in participantIds) {
        await txn.insert('expense_participants', {
          'expense_id': expenseId,
          'member_id': mid,
        });
      }
      return expenseId;
    });
  }
  Future<void> softDeleteExpense(int expenseId) async {
    final db = await _db;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.update(
      'expenses',
      {'deleted_at': nowSec},
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }
  Future<void> undoDeleteExpense(int id) async {
    final db = await _db;
    await db.update(
      'expenses',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> listExpenses(int groupId) async {
    final db = await _db;
    return db.query('expenses', where: 'group_id = ? AND deleted_at IS NULL', whereArgs: [groupId], orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> listParticipants(int expenseId) async {
    final db = await _db;
    return db.query('expense_participants', where: 'expense_id = ? AND deleted_at IS NULL', whereArgs: [expenseId]);
  }
  Future<void> updateExpenseTitle(int expenseId, String? title) async {
    final db = await _db;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      'expenses',
      {'title': title, 'updated_at': nowSec},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [expenseId],
    );
  }
  Future<void> updateExpense(int id, {required String title, required double amount}) async {
    final db = await _db;
    await db.update(
      'expenses',
      {
        'title': title,
        'amount': amount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  Future<bool> hasActiveExpenses(int groupId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT 1 FROM expenses WHERE group_id = ? AND deleted_at IS NULL LIMIT 1',
      [groupId],
    );
    return rows.isNotEmpty;
  }
}