import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/notes_repository.dart';
import 'note_detail_body.dart';

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});

  final int noteId;

  Future<void> _copySnapshot(
    BuildContext context,
    WidgetRef ref,
    String mode,
  ) async {
    final repo = ref.read(notesRepositoryProvider);
    final note = await repo.getNote(noteId);
    if (note == null || !context.mounted) return;
    final tags = await repo.tagsForNote(noteId);
    final text = mode == 'json'
        ? formatNoteJsonFromRow(note, tags)
        : formatNoteAsMarkdown(note, tags);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mode == 'json' ? 'Saved note JSON copied' : 'Saved note Markdown copied'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Note'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Copy saved note',
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'md',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Copy Markdown (saved)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'json',
                child: Row(
                  children: [
                    Icon(Icons.code, size: 20),
                    SizedBox(width: 12),
                    Text('Copy JSON (saved)'),
                  ],
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'md' || v == 'json') {
                unawaited(_copySnapshot(context, ref, v));
              }
            },
          ),
        ],
      ),
      body: NoteDetailBody(
        noteId: noteId,
        onDeleted: () {
          if (context.mounted) context.pop();
        },
      ),
    );
  }
}
