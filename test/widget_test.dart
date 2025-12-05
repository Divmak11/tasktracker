// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:todo_planner/data/providers/theme_provider.dart';
import 'package:todo_planner/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Create a ThemeProvider for testing
    final themeProvider = ThemeProvider();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(themeProvider: themeProvider));

    // Verify app loads without crashing
    await tester.pumpAndSettle();
  });
}
