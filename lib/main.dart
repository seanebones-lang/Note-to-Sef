import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/note_app.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container.read(notesRepositoryProvider).seedIfEmpty();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NoteToSelfApp(),
    ),
  );
}
