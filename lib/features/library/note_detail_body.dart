import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../data/notes_repository.dart';
import '../../utils/debouncer.dart';

/// Shared editor for a note (full screen or split-pane).
class NoteDetailBody extends ConsumerStatefulWidget {
  const NoteDetailBody({super.key, required this.noteId, this.onDeleted});

  final int noteId;
  final VoidCallback? onDeleted;

  @override
  ConsumerState<NoteDetailBody> createState() => _NoteDetailBodyState();
}

class _NoteDetailBodyState extends ConsumerState<NoteDetailBody> {
  late TextEditingController _title;
  late TextEditingController _body;
  late Debouncer _debouncer;
  bool _loaded = false;
  List<Tag> _allTags = [];
  Set<int> _selectedTagIds = {};
  List<Category> _categories = [];
  int? _categoryId;
  bool _pinned = false;
  bool _archived = false;

  @override
  void initState() {
    super.initState();
    _debouncer = Debouncer(duration: const Duration(milliseconds: 450));
    _title = TextEditingController();
    _body = TextEditingController();
    _load();
  }

  @override
  void didUpdateWidget(covariant NoteDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _load();
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    final id = widget.noteId;
    final titleText = _title.text.trim().isEmpty ? null : _title.text.trim();
    final bodyText = _body.text;
    final cat = _categoryId;
    final tags = _selectedTagIds.toList();
    final repo = ref.read(notesRepositoryProvider);
    unawaited(
      repo
          .updateNote(
            id: id,
            title: titleText,
            body: bodyText,
            categoryId: Value(cat),
          )
          .then((_) => repo.setNoteTags(id, tags)),
    );
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loaded = false);
    final repo = ref.read(notesRepositoryProvider);
    final note = await repo.getNote(widget.noteId);
    final tags = await repo.allTags();
    final categories = await repo.allCategories();
    if (note == null || !mounted) return;
    final noteTags = await repo.tagsForNote(widget.noteId);
    setState(() {
      _title.text = note.title ?? '';
      _body.text = note.body;
      _categoryId = note.categoryId;
      _allTags = tags;
      _categories = categories;
      _selectedTagIds = noteTags.map((t) => t.id).toSet();
      _pinned = note.pinned;
      _archived = note.archived;
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    try {
      final repo = ref.read(notesRepositoryProvider);
      await repo.updateNote(
        id: widget.noteId,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        body: _body.text,
        categoryId: Value(_categoryId),
      );
      await repo.setNoteTags(widget.noteId, _selectedTagIds.toList());
    } catch (e, st) {
      debugPrint('Note save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  void _schedulePersist() {
    _debouncer.run(() {
      unawaited(_persist());
    });
  }

  Future<void> _delete() async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.deleteNote(widget.noteId);
    widget.onDeleted?.call();
  }

  Future<void> _togglePin() async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.updateNote(id: widget.noteId, pinned: !_pinned);
    if (mounted) setState(() => _pinned = !_pinned);
  }

  Future<void> _toggleArchive() async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.updateNote(id: widget.noteId, archived: !_archived);
    if (mounted) setState(() => _archived = !_archived);
  }

  Future<void> _duplicateNote() async {
    final repo = ref.read(notesRepositoryProvider);
    final title = _title.text.trim();
    final newTitle = title.isEmpty ? null : '$title (copy)';
    final id = await repo.createNote(
      title: newTitle,
      body: _body.text,
      inInbox: false,
      categoryId: _categoryId,
    );
    await repo.setNoteTags(id, _selectedTagIds.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Duplicate created'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => context.push('/note/$id'),
        ),
      ),
    );
  }

  List<Tag> _selectedTagsForExport() {
    return _allTags.where((t) => _selectedTagIds.contains(t.id)).toList();
  }

  Future<void> _copyMarkdownToClipboard(BuildContext context) async {
    final md = formatNoteMarkdown(
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      body: _body.text,
      tags: _selectedTagsForExport(),
    );
    await Clipboard.setData(ClipboardData(text: md));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Markdown copied to clipboard')),
      );
    }
  }

  Future<void> _copyJsonToClipboard(BuildContext context) async {
    final repo = ref.read(notesRepositoryProvider);
    final note = await repo.getNote(widget.noteId);
    if (note == null || !context.mounted) return;
    final json = formatNoteJson(
      id: note.id,
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      body: _body.text,
      tags: _selectedTagsForExport(),
      pinned: note.pinned,
      inInbox: note.inInbox,
      archived: note.archived,
      categoryId: _categoryId,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_archived)
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Archived — hidden from the main list unless you include archived notes.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_toggleArchive()),
                    child: const Text('Restore'),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    hintText: 'Title (optional)',
                    border: InputBorder.none,
                  ),
                  style: theme.textTheme.titleLarge,
                  onChanged: (_) => _schedulePersist(),
                ),
              ),
              IconButton(
                tooltip: 'Pin',
                onPressed: _togglePin,
                icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'copy_md',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Copy as Markdown'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_json',
                    child: Row(
                      children: [
                        Icon(Icons.code, size: 20),
                        SizedBox(width: 12),
                        Text('Copy as JSON'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'dup',
                    child: Row(
                      children: [
                        Icon(Icons.copy_all_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Duplicate note'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          _archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(_archived ? 'Restore from archive' : 'Archive'),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'copy_md') {
                    unawaited(_copyMarkdownToClipboard(context));
                  } else if (v == 'copy_json') {
                    unawaited(_copyJsonToClipboard(context));
                  } else if (v == 'dup') {
                    unawaited(_duplicateNote());
                  } else if (v == 'archive') {
                    unawaited(_toggleArchive());
                  }
                },
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete note?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && mounted) await _delete();
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<int?>(
            key: ValueKey(_categoryId),
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('None')),
              ..._categories.map(
                (Category c) =>
                    DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
              ),
            ],
            onChanged: (v) {
              setState(() => _categoryId = v);
              _schedulePersist();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'New tag',
                    hintText: 'Type and press Enter',
                    isDense: true,
                  ),
                  onSubmitted: (v) async {
                    final name = v.trim();
                    if (name.isEmpty) return;
                    final repo = ref.read(notesRepositoryProvider);
                    final id = await repo.ensureTag(name);
                    if (!mounted) return;
                    final tags = await repo.allTags();
                    setState(() {
                      _selectedTagIds.add(id);
                      _allTags = tags;
                    });
                    await repo.setNoteTags(
                      widget.noteId,
                      _selectedTagIds.toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allTags.map((Tag t) {
              final selected = _selectedTagIds.contains(t.id);
              return FilterChip(
                label: Text(t.name),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedTagIds.add(t.id);
                    } else {
                      _selectedTagIds.remove(t.id);
                    }
                  });
                  _schedulePersist();
                },
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _body,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Write your thought…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => _schedulePersist(),
            ),
          ),
        ),
      ],
    );
  }
}
