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
        'created_at': DateTime.now().millisecondsSinceEpoch,
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

  Future<List<Map<String, dynamic>>> listExpenses(int groupId) async {
    final db = await _db;
    return db.query('expenses', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> listParticipants(int expenseId) async {
    final db = await _db;
    return db.query('expense_participants', where: 'expense_id = ?', whereArgs: [expenseId]);
  }
}