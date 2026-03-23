import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/notes_repository.dart';

/// Unsorted thoughts — triage into categories/tags or move to library.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(notesRepositoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inbox'),
            Text(
              'Triage unsorted thoughts',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<NoteView>>(
        stream: repo.watchNotes(inboxOnly: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load inbox.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            final cs = theme.colorScheme;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 72, color: cs.outline),
                    const SizedBox(height: 16),
                    Text(
                      'Inbox is clear',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'New captures land here when you choose “Send to inbox”.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final df = DateFormat.yMMMd().add_jm();
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final nv = items[i];
              final n = nv.note;
              final preview = n.body.trim().isEmpty
                  ? (n.title ?? 'Empty')
                  : n.body.trim();
              final short = preview.length > 100
                  ? '${preview.substring(0, 100)}…'
                  : preview;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(
                    n.title?.isNotEmpty == true ? n.title! : 'Untitled',
                  ),
                  subtitle: Text(
                    '$short\n${df.format(n.updatedAt)}',
                    maxLines: 3,
                  ),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: const Text('Move to library'),
                      subtitle: const Text('Mark as sorted (leave inbox)'),
                      onTap: () async {
                        await repo.updateNote(id: n.id, inInbox: false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Moved to library')),
                          );
                          setState(() {});
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Open'),
                      onTap: () => context.push('/note/${n.id}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.label_outline),
                      title: const Text('Assign category…'),
                      onTap: () => _pickCategory(context, n.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context, int noteId) async {
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(c).height * 0.55,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Category',
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: const Text('Clear category'),
                        onTap: () async {
                          await repo.updateNote(
                            id: noteId,
                            categoryId: const Value(null),
                          );
                          if (c.mounted) Navigator.pop(c);
                          setState(() {});
                        },
                      ),
                      ...categories.map(
                        (cat) => ListTile(
                          title: Text(cat.name),
                          onTap: () async {
                            await repo.updateNote(
                              id: noteId,
                              categoryId: Value(cat.id),
                            );
                            if (c.mounted) Navigator.pop(c);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
