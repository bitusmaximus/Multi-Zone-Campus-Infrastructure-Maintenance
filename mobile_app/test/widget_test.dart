import 'package:campus_dispatch_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Renders BduDispatchApp and displays Sign in / Register button', (WidgetTester tester) async {
    await tester.pumpWidget(const BduDispatchApp(client: null));
    await tester.pumpAndSettle();

    expect(find.text('BDU Facilities'), findsOneWidget);
    expect(find.text('CAMPUS DISPATCH'), findsOneWidget);
    expect(find.text('Sign in / Register'), findsOneWidget);
  });

  testWidgets('Opens Auth Dialog and enforces university email domain', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const BduDispatchApp(client: null));
    await tester.pumpAndSettle();

    // Tap Sign in / Register button
    await tester.tap(find.text('Sign in / Register'));
    await tester.pumpAndSettle();

    // Verify dialog title and initial Sign In state
    expect(find.text('Student Sign In'), findsOneWidget);

    // Switch to Student Register
    await tester.tap(find.text('Student Register'));
    await tester.pumpAndSettle();

    // Verify registration fields and university-only notice
    expect(find.text('Student Registration'), findsOneWidget);
    expect(find.textContaining('University Only:'), findsOneWidget);
    expect(find.text('Official University Email (@bdu.edu.et)'), findsOneWidget);

    // Enter a non-university email
    final emailField = find.widgetWithText(TextFormField, 'e.g. student@bdu.edu.et');
    await tester.enterText(emailField, 'student@gmail.com');

    // Scroll to submit button and tap
    final submitButton = find.text('Create Student Account');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify error is displayed for non-university email
    expect(find.text('Must be an official university email ending in @bdu.edu.et'), findsOneWidget);

    // Now enter valid university email
    await tester.enterText(emailField, 'student@bdu.edu.et');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // The university email error should be gone
    expect(find.text('Must be an official university email ending in @bdu.edu.et'), findsNothing);
  });
}
