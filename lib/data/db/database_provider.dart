import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'alman_usulu.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        // Enforce foreign key constraints (FK checks) in SQLite
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // v2 schema (fresh installs get the latest)
        await db.execute('''
          CREATE TABLE groups(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER,
            deleted_at INTEGER
          );
        ''');

        await db.execute('''
          CREATE TABLE members(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            updated_at INTEGER,
            deleted_at INTEGER,
            FOREIGN KEY(group_id) REFERENCES groups(id)
          );
        ''');

        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL,
            title TEXT,
            amount REAL NOT NULL,
            payer_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER,
            deleted_at INTEGER,
            FOREIGN KEY(group_id) REFERENCES groups(id),
            FOREIGN KEY(payer_id) REFERENCES members(id)
          );
        ''');

        await db.execute('''
          CREATE TABLE expense_participants(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expense_id INTEGER NOT NULL,
            member_id INTEGER NOT NULL,
            deleted_at INTEGER,
            FOREIGN KEY(expense_id) REFERENCES expenses(id),
            FOREIGN KEY(member_id) REFERENCES members(id)
          );
        ''');

        // Helpful indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_members_group ON members(group_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_group ON expenses(group_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_payer ON expenses(payer_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_parts_expense ON expense_participants(expense_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_parts_member ON expense_participants(member_id);');

        // Convenience VIEWS (active rows only)
        await db.execute('''
          CREATE VIEW IF NOT EXISTS v_groups_active AS
          SELECT * FROM groups WHERE deleted_at IS NULL;
        ''');
        await db.execute('''
          CREATE VIEW IF NOT EXISTS v_members_active AS
          SELECT * FROM members
          WHERE deleted_at IS NULL AND is_active = 1;
        ''');
        await db.execute('''
          CREATE VIEW IF NOT EXISTS v_expenses_active AS
          SELECT * FROM expenses WHERE deleted_at IS NULL;
        ''');
        await db.execute('''
          CREATE VIEW IF NOT EXISTS v_expense_participants_active AS
          SELECT * FROM expense_participants WHERE deleted_at IS NULL;
        ''');

        // TRIGGERS: auto set updated_at on UPDATE; set created_at if NULL on INSERT (where available)
        // groups
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS trg_groups_set_updated_at
          AFTER UPDATE ON groups
          FOR EACH ROW
          BEGIN
            UPDATE groups SET updated_at = strftime('%s','now') WHERE id = NEW.id;
          END;
        ''');
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS trg_groups_set_created_at
          BEFORE INSERT ON groups
          FOR EACH ROW
          WHEN NEW.created_at IS NULL
          BEGIN
            SELECT CASE WHEN (NEW.created_at IS NULL) THEN
              RAISE(IGNORE)
            END;
          END;
        ''');

        // members (no created_at column; only updated_at)
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS trg_members_set_updated_at
          AFTER UPDATE ON members
          FOR EACH ROW
          BEGIN
            UPDATE members SET updated_at = strftime('%s','now') WHERE id = NEW.id;
          END;
        ''');

        // expenses
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS trg_expenses_set_updated_at
          AFTER UPDATE ON expenses
          FOR EACH ROW
          BEGIN
            UPDATE expenses SET updated_at = strftime('%s','now') WHERE id = NEW.id;
          END;
        ''');
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS trg_expenses_set_created_at
          BEFORE INSERT ON expenses
          FOR EACH ROW
          WHEN NEW.created_at IS NULL
          BEGIN
            SELECT CASE WHEN (NEW.created_at IS NULL) THEN
              RAISE(IGNORE)
            END;
          END;
        ''');

        // expense_participants (only updated_at via parent updates not needed; maintain deleted_at manually)
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add soft-delete & audit columns, plus indexes
          final batch = db.batch();
          batch.execute('ALTER TABLE groups ADD COLUMN updated_at INTEGER');
          batch.execute('ALTER TABLE groups ADD COLUMN deleted_at INTEGER');

          batch.execute('ALTER TABLE members ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
          batch.execute('ALTER TABLE members ADD COLUMN updated_at INTEGER');
          batch.execute('ALTER TABLE members ADD COLUMN deleted_at INTEGER');

          batch.execute('ALTER TABLE expenses ADD COLUMN updated_at INTEGER');
          batch.execute('ALTER TABLE expenses ADD COLUMN deleted_at INTEGER');

          batch.execute('ALTER TABLE expense_participants ADD COLUMN deleted_at INTEGER');

          batch.execute('CREATE INDEX IF NOT EXISTS idx_members_group ON members(group_id)');
          batch.execute('CREATE INDEX IF NOT EXISTS idx_expenses_group ON expenses(group_id)');
          batch.execute('CREATE INDEX IF NOT EXISTS idx_expenses_payer ON expenses(payer_id)');
          batch.execute('CREATE INDEX IF NOT EXISTS idx_parts_expense ON expense_participants(expense_id)');
          batch.execute('CREATE INDEX IF NOT EXISTS idx_parts_member ON expense_participants(member_id)');

          await batch.commit(noResult: true);

          // Ensure views & triggers exist after v2 migration
          await db.execute('CREATE VIEW IF NOT EXISTS v_groups_active AS SELECT * FROM groups WHERE deleted_at IS NULL;');
          await db.execute('CREATE VIEW IF NOT EXISTS v_members_active AS SELECT * FROM members WHERE deleted_at IS NULL AND is_active = 1;');
          await db.execute('CREATE VIEW IF NOT EXISTS v_expenses_active AS SELECT * FROM expenses WHERE deleted_at IS NULL;');
          await db.execute('CREATE VIEW IF NOT EXISTS v_expense_participants_active AS SELECT * FROM expense_participants WHERE deleted_at IS NULL;');

          await db.execute('CREATE TRIGGER IF NOT EXISTS trg_groups_set_updated_at AFTER UPDATE ON groups BEGIN UPDATE groups SET updated_at = strftime(\'%s\',\'now\') WHERE id = NEW.id; END;');
          await db.execute('CREATE TRIGGER IF NOT EXISTS trg_members_set_updated_at AFTER UPDATE ON members BEGIN UPDATE members SET updated_at = strftime(\'%s\',\'now\') WHERE id = NEW.id; END;');
          await db.execute('CREATE TRIGGER IF NOT EXISTS trg_expenses_set_updated_at AFTER UPDATE ON expenses BEGIN UPDATE expenses SET updated_at = strftime(\'%s\',\'now\') WHERE id = NEW.id; END;');
        }
      },
    );
  }
  // ---------- Helper methods for undo / edit flows ----------

  Future<void> softDeleteGroup(int id) async {
    final db = await this.db; // ensure we get an opened Database instance
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      'groups',
      {'deleted_at': nowSec, 'updated_at': nowSec},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> undoDeleteGroup(int id) async {
    final db = await this.db;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      'groups',
      {'deleted_at': null, 'updated_at': nowSec},
      where: 'id = ? AND deleted_at IS NOT NULL',
      whereArgs: [id],
    );
  }

  Future<void> updateGroupName(int id, String name) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('groups', {'name': name, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> softDeleteMember(int id) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('members', {'deleted_at': now, 'updated_at': now}, where: 'id = ? AND deleted_at IS NULL', whereArgs: [id]);
  }

  Future<void> undoDeleteMember(int id) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('members', {'deleted_at': null, 'is_active': 1, 'updated_at': now}, where: 'id = ? AND deleted_at IS NOT NULL', whereArgs: [id]);
  }

  Future<void> updateMemberName(int id, String name) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('members', {'name': name, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setMemberActive(int id, bool active) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('members', {'is_active': active ? 1 : 0, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> softDeleteExpense(int id) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('expenses', {'deleted_at': now, 'updated_at': now}, where: 'id = ? AND deleted_at IS NULL', whereArgs: [id]);
  }

  Future<void> undoDeleteExpense(int id) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('expenses', {'deleted_at': null, 'updated_at': now}, where: 'id = ? AND deleted_at IS NOT NULL', whereArgs: [id]);
  }

  Future<void> updateExpense({required int id, String? title, double? amount, int? payerId}) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final data = <String, Object?>{'updated_at': now};
    if (title != null) data['title'] = title;
    if (amount != null) data['amount'] = amount;
    if (payerId != null) data['payer_id'] = payerId;
    await db.update('expenses', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> softDeleteExpenseParticipant(int id) async {
    final db = await this.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update('expense_participants', {'deleted_at': now}, where: 'id = ? AND deleted_at IS NULL', whereArgs: [id]);
  }

  Future<void> undoDeleteExpenseParticipant(int id) async {
    final db = await this.db;
    await db.update('expense_participants', {'deleted_at': null}, where: 'id = ? AND deleted_at IS NOT NULL', whereArgs: [id]);
  }
}