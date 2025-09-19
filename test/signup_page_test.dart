import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:albocarride/screens/auth/signup_page.dart';

void main() {
  group('SignupPage Tests', () {
    testWidgets('SignupPage renders correctly for driver role', (
      WidgetTester tester,
    ) async {
      // Build our widget
      await tester.pumpWidget(MaterialApp(home: SignupPage(role: 'driver')));

      // Verify the page renders with correct title
      expect(find.text('Sign Up as Driver'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Join AlboCarRide as a driver'), findsOneWidget);

      // Verify form fields are present
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
    });

    testWidgets('SignupPage renders correctly for customer role', (
      WidgetTester tester,
    ) async {
      // Build our widget
      await tester.pumpWidget(MaterialApp(home: SignupPage(role: 'customer')));

      // Verify the page renders with correct title
      expect(find.text('Sign Up as Customer'), findsOneWidget);
      expect(find.text('Join AlboCarRide as a customer'), findsOneWidget);
    });

    testWidgets('Phone number validation works', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignupPage(role: 'driver')));

      // Test empty phone number validation
      final phoneField = find.byType(TextFormField).first;
      await tester.enterText(phoneField, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      // Should show validation error
      await tester.pump();
      expect(find.text('Please enter your phone number'), findsOneWidget);

      // Test invalid phone number (too short)
      await tester.enterText(phoneField, '123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Please enter a valid phone number'), findsOneWidget);

      // Test valid phone number
      await tester.enterText(phoneField, '1234567890');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Please enter a valid phone number'), findsNothing);
    });

    testWidgets('Full name validation works', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignupPage(role: 'driver')));

      // Test empty full name validation
      final nameFields = find.byType(TextFormField);
      final nameField = nameFields.at(1); // Second text field
      await tester.enterText(nameField, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      // Should show validation error
      await tester.pump();
      expect(find.text('Please enter your full name'), findsOneWidget);

      // Test valid full name
      await tester.enterText(nameField, 'John Doe');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Please enter your full name'), findsNothing);
    });

    testWidgets('Send Verification Code button is present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: SignupPage(role: 'driver')));

      expect(find.text('Send Verification Code'), findsOneWidget);
    });
  });
}
