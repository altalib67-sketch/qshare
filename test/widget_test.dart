import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qshare/main.dart';

void main() {
  testWidgets('app builds a first frame', (WidgetTester tester) async {
    await tester.pumpWidget(const QShareApp());
    await tester.pump();
    // First frame is the permissions gate (loading while it checks
    // stored state); the full UI needs platform channels.
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.textContaining('QShare').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
