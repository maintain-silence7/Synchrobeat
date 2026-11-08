// SynchroBeat smoke test: verifies the app boots into offline demo mode
// and lands on the login screen without real backend credentials.
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrobeat_app/app.dart';
import 'package:synchrobeat_app/core/di/injection.dart';

void main() {
  setUpAll(() async {
    await initDependencies();
  });

  testWidgets('App boots to the SynchroBeat login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SynchroBeatApp());
    // Let the auth restore future resolve (2s timeout in tests) and redirect.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('SynchroBeat'), findsOneWidget);
    expect(
      find.text('Synchronized Group Audio Streaming'),
      findsOneWidget,
    );
    expect(find.text('Explore with demo account'), findsOneWidget);
  });
}
