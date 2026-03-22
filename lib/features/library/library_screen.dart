import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../data/notes_repository.dart';
import '../../utils/debouncer.dart';
import 'note_detail_body.dart';

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  late final Debouncer _searchDebouncer;

  String _debouncedQuery = '';
  int? _categoryFilter;
  int? _tagFilter;
  bool _includeArchived = false;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _searchDebouncer = Debouncer(duration: const Duration(milliseconds: 280));
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openNote(int id, bool wide) {
    if (wide) {
      setState(() => _selectedId = id);
    } else {
      context.push('/note/$id');
    }
  }

  void _clearSearch() {
    _searchDebouncer.cancel();
    _searchController.clear();
    setState(() => _debouncedQuery = '');
  }

  bool get _hasActiveFilters =>
      _debouncedQuery.isNotEmpty || _categoryFilter != null || _tagFilter != null || _includeArchived;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(notesRepositoryProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final theme = Theme.of(context);
    final meta = Platform.isMacOS || Platform.isIOS;

    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Manage categories',
            onPressed: () => _manageCategories(context),
            icon: const Icon(Icons.folder_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              focusNode: _searchFocus,
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search thoughts…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {});
                _searchDebouncer.run(() {
                  if (mounted) setState(() => _debouncedQuery = v);
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<NoteView>>(
        stream: repo.watchNotes(
          inboxOnly: false,
          categoryId: _categoryFilter,
          tagIdFilter: _tagFilter,
          includeArchived: _includeArchived,
          ftsQuery: _debouncedQuery.isEmpty ? null : _debouncedQuery,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load notes.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return _hasActiveFilters
                ? _EmptyFiltered(theme: theme)
                : _EmptyLibrary(onNew: () => context.push('/capture'), theme: theme);
          }

          final list = ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final nv = items[i];
              final n = nv.note;
              final preview = n.body.trim().isEmpty ? (n.title ?? 'Empty note') : n.body.trim();
              final short = preview.length > 120 ? '${preview.substring(0, 120)}…' : preview;
              final df = DateFormat.yMMMd().add_jm();
              final tile = Material(
                color: wide && _selectedId == n.id
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : null,
                child: ListTile(
                  selected: wide && _selectedId == n.id,
                  leading: (n.archived || n.pinned)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (n.archived)
                              Icon(Icons.archive_outlined, size: 18, color: theme.colorScheme.outline),
                            if (n.pinned)
                              Icon(Icons.push_pin, size: 20, color: theme.colorScheme.primary),
                          ],
                        )
                      : null,
                  title: Text(
                    n.title?.isNotEmpty == true ? n.title! : 'Untitled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(short, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(df.format(n.updatedAt), style: theme.textTheme.labelSmall),
                  onTap: () => _openNote(n.id, wide),
                ),
              );
              return Opacity(
                opacity: n.archived ? 0.72 : 1,
                child: tile,
              );
            },
          );

          final chips = _FilterChips(
            categoryFilter: _categoryFilter,
            tagFilter: _tagFilter,
            includeArchived: _includeArchived,
            onCategoryChanged: (v) => setState(() {
              _categoryFilter = v;
              _selectedId = null;
            }),
            onTagChanged: (v) => setState(() {
              _tagFilter = v;
              _selectedId = null;
            }),
            onIncludeArchivedChanged: (v) => setState(() {
              _includeArchived = v;
              _selectedId = null;
            }),
          );

          final filterRow = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: chips,
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                filterRow,
                Expanded(child: list),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    filterRow,
                    Expanded(child: list),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _selectedId == null
                    ? _SelectNoteHint(theme: theme)
                    : NoteDetailBody(
                        key: ValueKey(_selectedId),
                        noteId: _selectedId!,
                        onDeleted: () => setState(() => _selectedId = null),
                      ),
              ),
            ],
          );
        },
      ),
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(
          meta ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyF,
        ): const _FocusSearchIntent(),
      },
      child: Actions(
        actions: {
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocus.requestFocus();
              return null;
            },
          ),
        },
        child: scaffold,
      ),
    );
  }

  Future<void> _manageCategories(BuildContext context) async {
    final repo = ref.read(notesRepositoryProvider);
    final categories = await repo.allCategories();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Categories', style: Theme.of(c).textTheme.titleMedium),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...categories.map(
                        (cat) => ListTile(
                          title: Text(cat.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await repo.deleteCategory(cat.id);
                              if (c.mounted) Navigator.pop(c);
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('New category'),
                  onTap: () async {
                    final name = await _promptText(c, title: 'Category name');
                    if (name != null && name.isNotEmpty) {
                      await repo.createCategory(name);
                    }
                    if (c.mounted) Navigator.pop(c);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _promptText(BuildContext context, {required String title}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onNew, required this.theme});

  final VoidCallback onNew;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 72, color: cs.outline),
            const SizedBox(height: 20),
            Text('No notes yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Capture a thought with your voice or the keyboard.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('New thought'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFiltered extends StatelessWidget {
  const _EmptyFiltered({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'No matches',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different words or clear filters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectNoteHint extends StatelessWidget {
  const _SelectNoteHint({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Select a note',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerStatefulWidget {
  const _FilterChips({
    required this.categoryFilter,
    required this.tagFilter,
    required this.includeArchived,
    required this.onCategoryChanged,
    required this.onTagChanged,
    required this.onIncludeArchivedChanged,
  });

  final int? categoryFilter;
  final int? tagFilter;
  final bool includeArchived;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onTagChanged;
  final ValueChanged<bool> onIncludeArchivedChanged;

  @override
  ConsumerState<_FilterChips> createState() => _FilterChipsState();
}

class _FilterChipsState extends ConsumerState<_FilterChips> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Category>>(
      stream: ref.watch(notesRepositoryProvider).watchCategories(),
      builder: (context, catSnap) {
        return StreamBuilder<List<Tag>>(
          stream: ref.watch(notesRepositoryProvider).watchTags(),
          builder: (context, tagSnap) {
            final cats = catSnap.data ?? [];
            final tags = tagSnap.data ?? [];
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All categories'),
                    selected: widget.categoryFilter == null,
                    onSelected: (_) => widget.onCategoryChanged(null),
                  ),
                  ...cats.map(
                    (Category c) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: FilterChip(
                        label: Text(c.name),
                        selected: widget.categoryFilter == c.id,
                        onSelected: (_) => widget.onCategoryChanged(c.id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('All tags'),
                    selected: widget.tagFilter == null,
                    onSelected: (_) => widget.onTagChanged(null),
                  ),
                  ...tags.map(
                    (Tag t) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: FilterChip(
                        label: Text(t.name),
                        selected: widget.tagFilter == t.id,
                        onSelected: (_) => widget.onTagChanged(t.id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    avatar: Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: widget.includeArchived
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.outline,
                    ),
                    label: const Text('Archived'),
                    selected: widget.includeArchived,
                    onSelected: widget.onIncludeArchivedChanged,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
