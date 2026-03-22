import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

final _router = createRouter();

class NoteToSelfApp extends ConsumerWidget {
  const NoteToSelfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AppShortcuts(
      router: _router,
      child: MaterialApp.router(
        title: 'Note to Self',
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}

/// Global shortcuts: Cmd/Ctrl+N opens capture.
class _AppShortcuts extends StatelessWidget {
  const _AppShortcuts({required this.child, required this.router});

  final Widget child;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final meta = Platform.isMacOS || Platform.isIOS;
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(
          meta ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyN,
        ): const NewNoteIntent(),
      },
      child: Actions(
        actions: {
          NewNoteIntent: CallbackAction<NewNoteIntent>(
            onInvoke: (_) {
              router.push('/capture');
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class NewNoteIntent extends Intent {
  const NewNoteIntent();
}
