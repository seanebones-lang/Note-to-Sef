import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/capture/capture_screen.dart';
import '../features/inbox/inbox_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/note_detail_screen.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/library',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: LibraryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: InboxScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/capture',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: '/note/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return NoteDetailScreen(noteId: id);
        },
      ),
    ],
  );
}
