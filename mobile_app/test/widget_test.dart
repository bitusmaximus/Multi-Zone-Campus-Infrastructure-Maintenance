import 'package:bdu_campus_maintenance/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Renders the app with its proper name and sign-in button', (tester) async {
    await tester.pumpWidget(const BduDispatchApp(client: null));
    await tester.pumpAndSettle();

    expect((tester.widget(find.byType(MaterialApp)) as MaterialApp).title, 'BDU Campus Maintenance');
    expect(find.text('BDU Facilities'), findsOneWidget);
    expect(find.text('CAMPUS DISPATCH'), findsOneWidget);
    expect(find.text('Sign in / Register'), findsOneWidget);
  });

  testWidgets('Validates university email during registration', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const BduDispatchApp(client: null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in / Register'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student Register'));
    await tester.pumpAndSettle();

    expect(find.text('Student Registration'), findsOneWidget);
    expect(find.textContaining('University Only:'), findsOneWidget);
    final emailField = find.widgetWithText(TextFormField, 'e.g. student@bdu.edu.et');
    await tester.enterText(emailField, 'student@gmail.com');
    final submit = find.text('Create Student Account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Must be an official university email ending in @bdu.edu.et'), findsOneWidget);
  });

  testWidgets('Shows password recovery from student sign in', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const BduDispatchApp(client: null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in / Register'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Send recovery code'), findsOneWidget);
    await tester.tap(find.text('Send recovery code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your official @bdu.edu.et email'), findsOneWidget);
  });

  testWidgets('Completes registration, verification, sign out, and sign in', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const BduDispatchApp(client: null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in / Register'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student Register'));
    await tester.pumpAndSettle();

    Future<void> enterField(String hint, String value) async {
      final field = find.widgetWithText(TextFormField, hint);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await enterField('e.g. Abebe Kebede', 'Abebe Kebede');
    await enterField('e.g. student@bdu.edu.et', 'abebe@bdu.edu.et');
    await enterField('e.g. Software Engineering, Medicine, Civil', 'Software Engineering');
    await enterField('Create a secure password', 'secure123');
    await enterField('Re-enter your password', 'secure123');
    final createAccount = find.text('Create Student Account');
    await tester.ensureVisible(createAccount);
    await tester.tap(createAccount);
    await tester.pumpAndSettle();
    expect(find.text('Verify University Email'), findsOneWidget);

    await enterField('123456', '123456');
    await tester.tap(find.text('Verify & Activate Student Account'));
    await tester.pumpAndSettle();
    expect(find.text('Abebe Kebede'), findsWidgets);

    await tester.tap(find.text('Abebe Kebede').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in / Register'));
    await tester.pumpAndSettle();
    await enterField('e.g. yourname@bdu.edu.et', 'abebe@bdu.edu.et');
    await enterField('Enter your password', 'secure123');
    await tester.tap(find.text('Sign In as Student'));
    await tester.pumpAndSettle();
    expect(find.text('abebe'), findsWidgets);
  });
}
