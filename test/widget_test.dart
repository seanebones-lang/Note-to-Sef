import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:note_to_self/app/note_app.dart';

void main() {
  testWidgets('App loads Library title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NoteToSelfApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Library'), findsWidgets);
  });
}
