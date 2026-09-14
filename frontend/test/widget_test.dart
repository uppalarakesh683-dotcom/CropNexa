import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets(
    'CropNexa app loads successfully and reveals intro & login',
    (WidgetTester tester) async {
      await tester.pumpWidget(const CropNexaApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Advance through journey to reveal CropNexa logo and login
      await tester.pump(const Duration(seconds: 8));

      expect(find.text('CROP NEXA'), findsWidgets);
    },
  );

  testWidgets(
    'Full flow: Antigravity Intro -> Login -> Choose Language -> Home',
    (WidgetTester tester) async {
      await tester.pumpWidget(const CropNexaApp());
      await tester.pump();

      // Skip / Fast-forward or advance time past animation
      await tester.pump(const Duration(seconds: 9));

      // Find 'Continue with Google' button on the Login UI
      final googleBtn = find.text('Continue with Google');
      expect(googleBtn, findsOneWidget);

      // Tap Google Sign-in
      await tester.tap(googleBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 700));

      // Now on Choose Language screen
      expect(find.text('Choose Your Language'), findsOneWidget);
      expect(find.text('Continue to Farm Intelligence'), findsOneWidget);

      // Tap Continue to Farm Intelligence
      await tester.tap(find.text('Continue to Farm Intelligence'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Now in CropNexa Home!
      expect(find.text('Home'), findsWidgets);
      expect(find.text('My Farm'), findsWidgets);
    },
  );

  testWidgets(
    'Email & Password Login -> Choose Language -> Home',
    (WidgetTester tester) async {
      await tester.pumpWidget(const CropNexaApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));

      // Enter email and password
      final emailField = find.widgetWithText(TextField, 'Email or Phone');
      final passwordField = find.widgetWithText(TextField, 'Password');

      await tester.enterText(emailField, 'farmer@cropnexa.ai');
      await tester.enterText(passwordField, 'smartfarming123');
      await tester.pump();

      // Tap Login button
      final loginBtn = find.text('Login');
      await tester.tap(loginBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 700));

      // Reached Choose Language screen
      expect(find.text('Choose Your Language'), findsOneWidget);

      // Tap Continue
      await tester.tap(find.text('Continue to Farm Intelligence'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Reached CropNexa Home
      expect(find.text('Home'), findsWidgets);
    },
  );
}