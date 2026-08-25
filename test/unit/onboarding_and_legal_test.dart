import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/services/onboarding_service.dart';
import 'package:reciept_logging/services/legal_document_service.dart';
import 'package:reciept_logging/ui/features/onboarding/views/onboarding_screen.dart';
import 'package:reciept_logging/ui/features/settings/views/legal_document_screen.dart';
import 'package:reciept_logging/ui/core/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.instance.loadPersistedTheme();
  });

  group('LegalDocumentService Unit Tests', () {
    test('LegalDocType enum mappings and titles', () {
      expect(LegalDocType.fromString('privacy'), equals(LegalDocType.privacy));
      expect(LegalDocType.fromString('privacy_policy'), equals(LegalDocType.privacy));
      expect(LegalDocType.fromString('terms'), equals(LegalDocType.terms));
      expect(LegalDocType.fromString('tos'), equals(LegalDocType.terms));
      expect(LegalDocType.fromString('cookies'), equals(LegalDocType.cookies));
      expect(LegalDocType.fromString('cookie_policy'), equals(LegalDocType.cookies));
      expect(LegalDocType.fromString('accessibility'), equals(LegalDocType.accessibility));
      expect(LegalDocType.fromString('a11y'), equals(LegalDocType.accessibility));
      expect(LegalDocType.fromString('unknown'), equals(LegalDocType.privacy));

      expect(LegalDocType.privacy.title, equals('Privacy Policy'));
      expect(LegalDocType.terms.title, equals('Terms of Service'));
      expect(LegalDocType.cookies.title, equals('Cookie & Storage Policy'));
      expect(LegalDocType.accessibility.title, equals('Accessibility Statement'));

      expect(LegalDocType.privacy.fileName, equals('PRIVACY_POLICY.md'));
      expect(LegalDocType.terms.fileName, equals('TERMS_OF_SERVICE.md'));
      expect(LegalDocType.cookies.fileName, equals('COOKIE_POLICY.md'));
      expect(LegalDocType.accessibility.fileName, equals('ACCESSIBILITY_STATEMENT.md'));
    });

    test('LegalDocumentService loadDocument returns non-empty markdown content', () async {
      final service = LegalDocumentService.instance;
      service.clearCache();

      for (final type in LegalDocType.values) {
        final content = await service.loadDocument(type);
        expect(content, isNotEmpty);
        expect(content.contains(type.title) || content.contains('#'), isTrue);
      }
    });
  });

  group('OnboardingService Unit Tests', () {
    test('Initial uncompleted state and completeOnboarding workflow', () async {
      final service = OnboardingService.instance;
      await service.resetForTesting();

      expect(service.hasCompletedOnboarding, isFalse);
      expect(service.hasAcceptedLegalTerms, isFalse);
      expect(service.legalTermsAcceptedVersion, isNull);
      expect(service.legalTermsAcceptedAt, isNull);

      await service.completeOnboarding(acceptLegal: true);

      expect(service.hasCompletedOnboarding, isTrue);
      expect(service.hasAcceptedLegalTerms, isTrue);
      expect(service.legalTermsAcceptedVersion, equals(OnboardingService.currentLegalVersion));
      expect(service.legalTermsAcceptedAt, isNotNull);

      // Verify persistence across new init
      await service.init();
      expect(service.hasCompletedOnboarding, isTrue);
      expect(service.hasAcceptedLegalTerms, isTrue);

      // Test reset
      await service.resetForTesting();
      expect(service.hasCompletedOnboarding, isFalse);
      expect(service.hasAcceptedLegalTerms, isFalse);
    });
  });

  group('LegalDocumentScreen Widget Tests', () {
    testWidgets('LegalDocumentScreen renders document tabs and loaded markdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const LegalDocumentScreen(initialDocType: LegalDocType.privacy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Terms of Service'), findsWidgets);
      expect(find.text('Cookies'), findsWidgets);
      expect(find.text('Accessibility'), findsWidgets);

      // Switch tab to Terms
      await tester.tap(find.text('Terms of Service').first);
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsWidgets);
    });
  });

  group('OnboardingScreen Widget Tests', () {
    testWidgets('OnboardingScreen displays first slide and skip button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receipt Logger'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('100% Offline-First Privacy'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Tap continue to go to slide 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Fast AI Vision OCR'), findsOneWidget);
    });

    testWidgets('OnboardingScreen Slide 4 circular checkmark indents and toggles check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap skip to go directly to slide 4
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Terms & Privacy Consent'), findsOneWidget);
      expect(find.text('I Agree & Get Started'), findsOneWidget);

      // Initially unselected - no check icon found
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Ensure the agreement row is scrolled into view and tap
      final agreementFinder = find.textContaining('I confirm that I am at least 13 years old');
      await tester.ensureVisible(agreementFinder);
      await tester.pumpAndSettle();
      await tester.tap(agreementFinder);
      await tester.pumpAndSettle();

      // Now selected - check icon appears
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap again to toggle off
      await tester.tap(agreementFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });
}
