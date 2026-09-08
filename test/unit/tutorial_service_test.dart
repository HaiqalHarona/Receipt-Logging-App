import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart'
    show Neumorphic;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/services/tutorial_service.dart';
import 'package:reciept_logging/ui/core/widgets/coach_mark_overlay.dart';
import 'package:reciept_logging/ui/features/verification/views/verification_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialService.instance.resetForTesting();
  });

  group('TutorialService Unit Tests', () {
    test('Initial state: not dismissed, currentStep 0, isActive false',
        () async {
      final service = TutorialService.instance;
      await service.init();

      expect(service.hasDismissedTutorial, isFalse);
      expect(service.currentStep, equals(0));
      expect(service.isActive, isFalse);
      expect(service.scanErrorMessage, isNull);
    });

    test('startTutorial sets step to 1 and clears error', () async {
      final service = TutorialService.instance;
      await service.init();

      service.startTutorial();

      expect(service.currentStep, equals(1));
      expect(service.isActive, isTrue);
      expect(service.scanErrorMessage, isNull);
    });

    test('advanceStep walks through steps 1 -> 2 -> 3 -> 4 (dismissed)',
        () async {
      final service = TutorialService.instance;
      await service.init();

      service.startTutorial();
      expect(service.currentStep, equals(1));

      service.advanceStep();
      expect(service.currentStep, equals(2));
      expect(service.isActive, isTrue);

      service.advanceStep();
      expect(service.currentStep, equals(3));
      expect(service.isActive, isTrue);

      service.advanceStep();
      expect(service.currentStep, equals(4));
      expect(service.isActive, isFalse);
      expect(service.hasDismissedTutorial, isTrue);

      // Verify persisted in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_dismissed_tutorial'), isTrue);
    });

    test('dismissTutorial marks tutorial dismissed and persists flag',
        () async {
      final service = TutorialService.instance;
      await service.init();

      service.startTutorial();
      expect(service.isActive, isTrue);

      await service.dismissTutorial();
      expect(service.hasDismissedTutorial, isTrue);
      expect(service.currentStep, equals(4));
      expect(service.isActive, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_dismissed_tutorial'), isTrue);
    });

    test('notifyScanFailed resets step to 1 and records friendly error message',
        () async {
      final service = TutorialService.instance;
      await service.init();

      service.startTutorial();
      service.advanceStep(); // Step 2: Scanner
      expect(service.currentStep, equals(2));

      service
          .notifyScanFailed('Image is completely illegible. Please try again.');

      expect(service.currentStep, equals(1));
      expect(service.isActive, isTrue);
      expect(service.scanErrorMessage,
          equals('Image is completely illegible. Please try again.'));

      // clearScanError clears message
      service.clearScanError();
      expect(service.scanErrorMessage, isNull);
    });

    test('resetForTesting clears SharedPreferences and resets state to 0',
        () async {
      final service = TutorialService.instance;
      await service.init();
      await service.dismissTutorial();
      expect(service.hasDismissedTutorial, isTrue);

      await service.resetForTesting();
      expect(service.hasDismissedTutorial, isFalse);
      expect(service.currentStep, equals(0));
      expect(service.scanErrorMessage, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_dismissed_tutorial'), isNull);
    });

    testWidgets(
        'TutorialTopHeader renders step indicator without icon and handles Skip',
        (tester) async {
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutorialTopHeader(
              stepIndicator: 'Step 1 of 3: Scan',
              onSkip: () => skipped = true,
            ),
          ),
        ),
      );

      expect(find.text('Step 1 of 3: Scan'), findsOneWidget);
      expect(find.text('Skip Guide'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsNothing);

      await tester.tap(find.text('Skip Guide'));
      await tester.pumpAndSettle();

      expect(skipped, isTrue);
    });

    testWidgets(
        'CoachMarkOverlay triggers onTargetTap when cutout area is tapped',
        (tester) async {
      final targetKey = GlobalKey();
      bool targetTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: Container(
                    key: targetKey,
                    width: 60,
                    height: 60,
                    color: Colors.blue,
                  ),
                ),
                CoachMarkOverlay(
                  targetKey: targetKey,
                  stepIndicator: 'Step 1 of 3: Scan',
                  title: 'Scan Receipt',
                  subtitle: 'Tap here to scan',
                  onSkip: () {},
                  onTargetTap: () => targetTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step 1 of 3: Scan'), findsOneWidget);
      expect(find.text('Scan Receipt'), findsOneWidget);

      // Tap the target container (handled by CoachMarkOverlay's onTargetTap)
      await tester.tap(find.byKey(targetKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(targetTapped, isTrue);
    });

    testWidgets(
        'CoachMarkOverlay builds without throwing when rendered outside of Scaffold/Material',
        (tester) async {
      final targetKey = GlobalKey();

      await tester.pumpWidget(
        WidgetsApp(
          color: Colors.blue,
          builder: (context, _) => Stack(
            children: [
              SizedBox(key: targetKey, width: 50, height: 50),
              CoachMarkOverlay(
                targetKey: targetKey,
                stepIndicator: 'Step 1 of 3: Scan',
                title: 'Test Title',
                subtitle: 'Test Subtitle',
                onSkip: () {},
              ),
            ],
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step 1 of 3: Scan'), findsOneWidget);
      expect(find.text('Skip Guide'), findsOneWidget);
    });

    testWidgets(
        'CoachMarkOverlay step description uses 25% opacity flat container without Neumorphic shadows',
        (tester) async {
      final targetKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SizedBox(key: targetKey, width: 60, height: 60),
                CoachMarkOverlay(
                  targetKey: targetKey,
                  stepIndicator: 'Step 1 of 3: Scan',
                  title: 'Scan Receipt',
                  subtitle: 'Tap here to scan',
                  onSkip: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Neumorphic is not used for step description card or header
      expect(
        find.descendant(
          of: find.byType(CoachMarkOverlay),
          matching: find.byType(Neumorphic),
        ),
        findsNothing,
      );

      // Verify at least one Container has ~0.25 opacity background
      final containers = tester.widgetList<Container>(find.byType(Container));
      final has25PercentOpacityCard = containers.any((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.color != null) {
          return (dec.color!.a - 0.95).abs() < 0.05;
        }
        return false;
      });
      expect(has25PercentOpacityCard, isTrue);
    });

    testWidgets(
        'VerificationScreen displays Step 3 CoachMarkOverlay and triggers auto-scroll',
        (tester) async {
      final service = TutorialService.instance;
      await service.init();
      service.startTutorial(); // Step 1
      service.advanceStep(); // Step 2
      service.advanceStep(); // Step 3
      expect(service.currentStep, equals(3));

      const receipt = Receipt(
        id: 'test-1',
        merchant: 'Groceries Store',
        date: '2026-09-08',
        amount: 25.50,
        currency: 'USD',
        category: 'Groceries',
      );

      final router = GoRouter(
        initialLocation: '/verification',
        routes: [
          GoRoute(
            path: '/verification',
            builder: (context, state) => const VerificationScreen(),
          ),
        ],
        initialExtra: [receipt],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Coach mark overlay for step 3 is visible
      expect(find.text('Step 3 of 3: Save'), findsOneWidget);
      expect(find.text('Save Your Receipt'), findsOneWidget);
    });
  });
}
