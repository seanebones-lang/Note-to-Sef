import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// User-facing view combining a note with category and tags.
class NoteView {
  NoteView({required this.note, this.category, required this.tags});

  final Note note;
  final Category? category;
  final List<Tag> tags;
}

/// Markdown export: optional H1 title, body, tag footer.
String formatNoteMarkdown({
  String? title,
  required String body,
  required List<Tag> tags,
}) {
  final b = StringBuffer();
  final t = title?.trim();
  if (t != null && t.isNotEmpty) {
    b.writeln('# $t');
    b.writeln();
  }
  b.write(body.trimRight());
  if (tags.isNotEmpty) {
    b.writeln();
    b.writeln();
    b.writeln('---');
    b.writeln(tags.map((x) => '#${x.name}').join(' '));
  }
  return b.toString();
}

String formatNoteAsMarkdown(Note note, List<Tag> tags) {
  return formatNoteMarkdown(title: note.title, body: note.body, tags: tags);
}

/// Portable JSON export for a single note.
String formatNoteJson({
  required int id,
  String? title,
  required String body,
  required List<Tag> tags,
  bool? pinned,
  bool? inInbox,
  bool? archived,
  int? categoryId,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'id': id,
    'title': title,
    'body': body,
    'pinned': pinned,
    'inInbox': inInbox,
    'archived': archived,
    'categoryId': categoryId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'tags': tags.map((t) => {'id': t.id, 'name': t.name}).toList(),
  });
}

String formatNoteJsonFromRow(Note note, List<Tag> tags) {
  return formatNoteJson(
    id: note.id,
    title: note.title,
    body: note.body,
    tags: tags,
    pinned: note.pinned,
    inInbox: note.inInbox,
    archived: note.archived,
    categoryId: note.categoryId,
    createdAt: note.createdAt,
    updatedAt: note.updatedAt,
  );
}

class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;

  /// FTS5-safe: prefix match per token.
  static String ftsMatchQuery(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll('"', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '"${w.replaceAll("'", " ")}"')
        .join(' AND ');
  }

  Future<int> createNote({
    String? title,
    String body = '',
    bool inInbox = true,
    int? categoryId,
  }) {
    final now = DateTime.now();
    return _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            title: Value(title),
            body: Value(body),
            categoryId: Value(categoryId),
            inInbox: Value(inInbox),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> updateNote({
    required int id,
    String? title,
    String? body,
    bool? inInbox,
    bool? pinned,
    bool? archived,

    /// Use [Value.absent()] to leave category unchanged, [Value(null)] to clear.
    Value<int?> categoryId = const Value.absent(),
  }) async {
    await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        body: body != null ? Value(body) : const Value.absent(),
        inInbox: inInbox != null ? Value(inInbox) : const Value.absent(),
        pinned: pinned != null ? Value(pinned) : const Value.absent(),
        archived: archived != null ? Value(archived) : const Value.absent(),
        categoryId: categoryId,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteNote(int id) async {
    await (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
  }

  Future<Note?> getNote(int id) {
    return (_db.select(
      _db.notes,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  Future<List<Tag>> tagsForNote(int noteId) => _tagsForNote(noteId);

  Stream<List<NoteView>> watchNotes({
    bool? inboxOnly,
    int? categoryId,
    int? tagIdFilter,
    bool includeArchived = false,
    String? ftsQuery,
  }) {
    final query = _db.select(_db.notes).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.notes.categoryId),
      ),
    ]);

    if (!includeArchived) {
      query.where(_db.notes.archived.equals(false));
    }

    if (inboxOnly == true) {
      query.where(_db.notes.inInbox.equals(true));
      query.where(_db.notes.archived.equals(false));
    } else if (inboxOnly == false) {
      query.where(_db.notes.inInbox.equals(false));
    }

    if (categoryId != null) {
      query.where(_db.notes.categoryId.equals(categoryId));
    }

    query.orderBy([
      OrderingTerm.desc(_db.notes.pinned),
      OrderingTerm.desc(_db.notes.updatedAt),
    ]);

    return query.watch().asyncMap((rows) async {
      var notes = await Future.wait(
        rows.map((row) async {
          final note = row.readTable(_db.notes);
          final category = row.readTableOrNull(_db.categories);
          final tags = await _tagsForNote(note.id);
          return NoteView(note: note, category: category, tags: tags);
        }),
      );

      if (tagIdFilter != null) {
        notes = notes
            .where((nv) => nv.tags.any((t) => t.id == tagIdFilter))
            .toList();
      }

      if (ftsQuery != null && ftsQuery.trim().isNotEmpty) {
        final q = ftsMatchQuery(ftsQuery);
        if (q.isEmpty) return notes;
        final ids = await _searchNoteIdsFts(q);
        notes = notes.where((nv) => ids.contains(nv.note.id)).toList();
      }

      return notes;
    });
  }

  Future<List<int>> _searchNoteIdsFts(String matchQuery) async {
    final rows = await _db
        .customSelect(
          'SELECT rowid AS id FROM notes_fts WHERE notes_fts MATCH ?',
          variables: [Variable<String>(matchQuery)],
          readsFrom: {_db.notes},
        )
        .get();
    return rows.map((r) => r.read<int>('id')).toList();
  }

  Future<List<Tag>> _tagsForNote(int noteId) async {
    final q = _db.select(_db.tags).join([
      innerJoin(_db.noteTags, _db.noteTags.tagId.equalsExp(_db.tags.id)),
    ])..where(_db.noteTags.noteId.equals(noteId));
    final rows = await q.get();
    return rows.map((r) => r.readTable(_db.tags)).toList();
  }

  Future<List<Tag>> allTags() {
    return (_db.select(
      _db.tags,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Stream<List<Tag>> watchTags() {
    return (_db.select(
      _db.tags,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<int> ensureTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Tag name empty');
    final existing = await (_db.select(
      _db.tags,
    )..where((t) => t.name.equals(trimmed))).getSingleOrNull();
    if (existing != null) return existing.id;
    return _db.into(_db.tags).insert(TagsCompanion.insert(name: trimmed));
  }

  Future<void> setNoteTags(int noteId, List<int> tagIds) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.noteTags,
      )..where((nt) => nt.noteId.equals(noteId))).go();
      for (final tid in tagIds) {
        await _db
            .into(_db.noteTags)
            .insert(
              NoteTagsCompanion.insert(noteId: noteId, tagId: tid),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<List<Category>> allCategories() {
    return (_db.select(_db.categories)..orderBy([
          (c) => OrderingTerm.asc(c.sortOrder),
          (c) => OrderingTerm.asc(c.name),
        ]))
        .get();
  }

  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)..orderBy([
          (c) => OrderingTerm.asc(c.sortOrder),
          (c) => OrderingTerm.asc(c.name),
        ]))
        .watch();
  }

  Future<int> createCategory(String name) {
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name.trim(),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteCategory(int id) async {
    await (_db.update(_db.notes)..where((n) => n.categoryId.equals(id))).write(
      const NotesCompanion(categoryId: Value(null)),
    );
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  /// One-time demo seed (idempotent checks by category names).
  Future<void> seedIfEmpty() async {
    final countQuery = _db.selectOnly(_db.categories)
      ..addColumns([_db.categories.id.count()]);
    final row = await countQuery.getSingle();
    final n = row.read(_db.categories.id.count()) ?? 0;
    if (n > 0) return;
    final now = DateTime.now();
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Ideas',
            sortOrder: const Value(0),
            createdAt: now,
          ),
        );
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Tasks',
            sortOrder: const Value(1),
            createdAt: now,
          ),
        );
    await _db.into(_db.tags).insert(TagsCompanion.insert(name: 'important'));
  }
}
