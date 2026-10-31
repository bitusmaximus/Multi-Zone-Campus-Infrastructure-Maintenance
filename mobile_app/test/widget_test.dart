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

  testWidgets('Opens Auth Dialog and switches between Sign In and Student Register', (WidgetTester tester) async {
    await tester.pumpWidget(const BduDispatchApp(client: null));
    await tester.pumpAndSettle();

    // Tap Sign in / Register button
    await tester.tap(find.text('Sign in / Register'));
    await tester.pumpAndSettle();

    // Verify dialog title and initial Sign In state
    expect(find.text('Student Sign In'), findsOneWidget);
    expect(find.text('Sign In as Student'), findsOneWidget);

    // Switch to Student Register
    await tester.tap(find.text('Student Register'));
    await tester.pumpAndSettle();

    // Verify registration fields are displayed
    expect(find.text('Student Registration'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Department / Faculty'), findsOneWidget);
    expect(find.text('Create Student Account'), findsOneWidget);
    expect(find.text('Role: Student (Campus Maintenance Reporter)'), findsOneWidget);
  });
}
