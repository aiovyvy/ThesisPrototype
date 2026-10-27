import 'dart:io';

import 'package:aiovy/core/brand/brand_mark.dart';
import 'package:aiovy/navigation/main_shell.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/screens/welcome/onboarding_screen.dart';
import 'package:aiovy/screens/welcome/welcome_screen.dart';
import 'package:aiovy/widgets/aiovy_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  setUpAll(loadTestFonts);

  group('Brand mark', () {
    test('every shape parses and stays inside the 160 × 160 canvas', () {
      for (final s in BrandMark.shapes) {
        final b = BrandMarkPainter.pathFor(s).getBounds();
        expect(b.left, greaterThanOrEqualTo(0));
        expect(b.top, greaterThanOrEqualTo(0));
        expect(b.right, lessThanOrEqualTo(BrandMark.canvas));
        expect(b.bottom, lessThanOrEqualTo(BrandMark.canvas));
      }
    });

    test('the committed SVG is generated from the same geometry', () {
      final svg = File('assets/brand/aiovy-symbol.svg').readAsStringSync();
      for (final s in BrandMark.shapes.where((s) => !s.isCircle)) {
        expect(svg, contains(s.d), reason: 'Regenerate with --dart-define=BRAND_EXPORT=true');
      }
    });

    testWidgets('logo variants render at small sizes and with large text', (tester) async {
      setScreen(tester, const Size(360, 640), textScale: 2);
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: Column(
              children: [
                AiovyLogoMark(size: 16),
                AiovyWordmark(height: 30),
                AiovyLogoMark(size: 24, monochrome: Colors.black),
                AiovyLogoStacked(symbolSize: 80),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('AIOVY, Maternal Care Intelligence'), findsWidgets);
    });
  });

  group('Welcome and onboarding', () {
    testWidgets('Get started walks through three pages to sign-in', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const WelcomeScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Smarter support for maternal${String.fromCharCode(0xA0)}care.'), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Start a synthetic assessment'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Understand the output'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Save and revisit'), findsOneWidget);

      await tester.tap(find.text('Continue to sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Skip goes straight to sign-in', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const OnboardingScreen()));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Sign in skips the introduction; Back returns to Welcome', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const WelcomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('with reduced motion the welcome is complete on the first frame', (tester) async {
      setScreen(tester, const Size(360, 780));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(testApp(const WelcomeScreen()));
      await tester.pump();
      final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);
      expect(opacities, everyElement(1.0));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Login', () {
    testWidgets('password visibility toggle is labelled and works', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const LoginScreen()));
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('empty fields are validated; valid input signs in', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter your email or clinical ID'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'demo@example.org');
      await tester.enterText(find.byType(TextFormField).last, 'x');
      await tester.tap(find.text('Sign in'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(MainShell), findsOneWidget);
    });
  });
}
