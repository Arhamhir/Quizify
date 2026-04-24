import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/screens/auth_page.dart';

void main() {
  testWidgets('Auth page renders Quizify title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthPage()),
    );

    expect(find.text('Quizify'), findsOneWidget);
  });
}
