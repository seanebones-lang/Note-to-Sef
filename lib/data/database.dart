import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().withDefault(const Constant(''))();
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get inInbox => boolean().withDefault(const Constant(true))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class NoteTags extends Table {
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

@DriftDatabase(tables: [Categories, Notes, Tags, NoteTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'note_to_self'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createFts();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // FTS5 can reject NULL indexed columns; recreate triggers with coalescing.
        await customStatement('DROP TRIGGER IF EXISTS notes_ai;');
        await customStatement('DROP TRIGGER IF EXISTS notes_ad;');
        await customStatement('DROP TRIGGER IF EXISTS notes_au;');
        await _createFtsTriggers();
      }
      if (from < 3) {
        // Only reindex FTS when title/body change. Running the FTS sync on every
        // UPDATE (e.g. category_id) can fail with SQL logic error on some SQLite builds.
        await customStatement('DROP TRIGGER IF EXISTS notes_au;');
        await _createNotesAuTrigger();
      }
    },
  );

  Future<void> _createFts() async {
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
  title,
  body,
  tokenize = 'porter unicode61'
);
''');
    await _createFtsTriggers();
  }

  Future<void> _createFtsTriggers() async {
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
  INSERT INTO notes_fts(rowid, title, body)
  VALUES (new.id, ifnull(new.title, ''), ifnull(new.body, ''));
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
  INSERT INTO notes_fts(notes_fts, rowid) VALUES('delete', old.id);
END;
''');
    await _createNotesAuTrigger();
  }

  Future<void> _createNotesAuTrigger() async {
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE OF title, body ON notes BEGIN
  INSERT INTO notes_fts(notes_fts, rowid) VALUES('delete', old.id);
  INSERT INTO notes_fts(rowid, title, body)
  VALUES (new.id, ifnull(new.title, ''), ifnull(new.body, ''));
END;
''');
  }
}
