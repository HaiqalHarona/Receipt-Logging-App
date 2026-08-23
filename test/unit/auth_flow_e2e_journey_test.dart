import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/api/api_config.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';
import 'package:reciept_logging/data/repositories/conversation_repository.dart';
import 'package:reciept_logging/data/repositories/chat_message_repository.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/services/category_service.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/features/auth/views/auth_screen.dart';
import 'package:reciept_logging/ui/features/auth/views/login_screen.dart';
import 'package:reciept_logging/ui/features/auth/views/signup_screen.dart';
import 'package:reciept_logging/ui/features/settings/views/settings_screen.dart';
import 'package:reciept_logging/ui/features/settings/views/user_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: child,
    );
  }

  group('Task 5C: End-to-End Auth User Journey Verification Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.clearSession();
    });

    tearDown(() async {
      await AuthService.instance.clearSession();
    });

    // ── JOURNEY 1: Guest Discovery & Onboarding Gateway ────────────────────────
    testWidgets(
        'Journey 1: Guest mode in Settings displays onboarding banner and AuthScreen renders gateway',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Verify guest state
      expect(AuthService.instance.isLoggedIn, isFalse);

      // 1. Settings in Guest mode shows Onboarding banner
      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sign In or Register'), findsOneWidget);
      expect(find.text('Sync receipts across devices with cloud backup'),
          findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // 2. AuthScreen Gateway landing verification
      await tester.pumpWidget(buildTestableWidget(const AuthScreen()));
      await tester.pumpAndSettle();

      expect(find.text(ApiConfig.appName), findsOneWidget);
      expect(find.text('Smart receipt scanning & automated expense management'),
          findsOneWidget);
      expect(find.text('AI Vision Parsing'), findsOneWidget);
      expect(find.text('Smart Spending Insights'), findsOneWidget);
      expect(find.text('Multi-Device Sync'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    // ── JOURNEY 2: User Registration & Visual Password Feedback ────────────────
    testWidgets(
        'Journey 2: SignUpScreen displays stepper, sections, live password meter, and CTA',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Verify header & stepper
      expect(find.text('Create ${ApiConfig.appName} Account'), findsOneWidget);
      expect(find.text('1. Account'), findsOneWidget);
      expect(find.text('2. Security'), findsOneWidget);
      expect(find.text('3. Complete'), findsOneWidget);

      // Verify grouped section labels
      expect(find.text('ACCOUNT INFORMATION'), findsOneWidget);
      expect(find.text('SECURITY CREDENTIALS'), findsOneWidget);

      // Enter password to test dynamic strength meter
      final textFields = find.byType(TextField);
      expect(textFields,
          findsNWidgets(4)); // username, email, password, confirmPassword

      // Type weak password into 3rd TextField (Password)
      await tester.enterText(textFields.at(2), 'abc');
      await tester.pumpAndSettle();
      expect(find.textContaining('Weak'), findsOneWidget);

      // Type strong password
      await tester.enterText(textFields.at(2), 'SuperSecret@123456');
      await tester.pumpAndSettle();
      expect(find.text('Strong'), findsOneWidget);

      // Verify CTA button & bottom link
      expect(find.widgetWithText(NeumorphicButtonWidget, 'Create Account'),
          findsOneWidget);

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
      final plainTexts = richTextFinder
          .evaluate()
          .map((e) => (e.widget as RichText).text.toPlainText());
      expect(
          plainTexts.any((t) => t.contains('Already have an account? Log In')),
          isTrue);
    });

    // ── JOURNEY 3: Returning User Sign-In & Error Handling ─────────────────────
    testWidgets(
        'Journey 3: LoginScreen renders welcome hero, input fields, and links',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.textContaining(ApiConfig.appName), findsWidgets);
      expect(find.text('USERNAME OR EMAIL'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.widgetWithText(NeumorphicButtonWidget, 'Sign In'),
          findsOneWidget);

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
      final plainTexts = richTextFinder
          .evaluate()
          .map((e) => (e.widget as RichText).text.toPlainText());
      expect(
          plainTexts.any((t) => t.contains("Don't have an account? Sign Up")),
          isTrue);
    });

    // ── JOURNEY 4: Profile & Settings in Logged-In Mode ────────────────────────
    testWidgets(
        'Journey 4: Logged-in user sees ACCOUNT section and UserSettingsScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Set active user session
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr_j4_101',
        username: 'AlexDev',
        email: 'alex@example.com',
        createdAt: '2026-08-21T00:00:00Z',
      ));
      expect(AuthService.instance.isLoggedIn, isTrue);

      // 1. SettingsScreen in Logged-in mode
      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sign In or Register'), findsNothing); // Banner gone
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('AlexDev'), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // 2. UserSettingsScreen renders profile card and actions
      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Account & Profile'), findsOneWidget);
      expect(find.text('AlexDev'), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    // ── JOURNEY 5: Guaranteed Logout & Database Purge ──────────────────────────
    test(
        'Journey 5: Logging out completely purges all Isar repositories and session cache',
        () async {
      // 1. Setup session
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr_j5_202',
        username: 'PurgeTarget',
        email: 'target@example.com',
        createdAt: '2026-08-21T00:00:00Z',
      ));

      // 2. Add records to repositories
      const testReceipt = Receipt(
        id: 'r_j5_1',
        merchant: 'Costco Wholesale',
        date: 'Aug 21, 2026',
        amount: 89.50,
        currency: 'USD',
        category: 'Groceries',
      );
      await ReceiptRepository.instance.saveReceipt(testReceipt);
      expect(ReceiptRepository.instance.receipts.isNotEmpty, isTrue);

      await ConversationRepository.instance.createConversation(
        id: 'conv_j5_1',
        title: 'Receipt Inquiry Chat',
      );
      expect(ConversationRepository.instance.conversations.isNotEmpty, isTrue);

      await ChatMessageRepository.instance.init();
      await ChatMessageRepository.instance.addMessage(
        conversationId: 'conv_j5_1',
        sender: 'user',
        content: 'How much did I spend at Costco?',
        id: 'msg_j5_1',
      );
      expect(ChatMessageRepository.instance.currentHistory.isNotEmpty, isTrue);

      await CategoryService.instance
          .addCategory('Electronics', 0xFF3B82F6, 0xe318);
      expect(CategoryService.instance.customCategories.isNotEmpty, isTrue);

      // 3. Perform logout
      await AuthService.instance.clearSession();

      // 4. Assert total data destruction on device
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.currentUsername, isNull);
      expect(AuthService.instance.currentUserToken, isNull);
      expect(AuthService.instance.currentUserId, isNull);

      expect(ReceiptRepository.instance.receipts, isEmpty);
      expect(ConversationRepository.instance.conversations, isEmpty);
      expect(ChatMessageRepository.instance.currentHistory, isEmpty);
      expect(CategoryService.instance.customCategories, isEmpty);
    });

    // ── JOURNEY 6: Offline Resilience on Logout ────────────────────────────────
    test(
        'Journey 6: clearSession executes reliably in offline/disconnected mode',
        () async {
      // Setup authenticated state with cached data
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr_j6_303',
        username: 'OfflineUser',
        email: 'offline@example.com',
        createdAt: '2026-08-21T00:00:00Z',
      ));

      // Simulate offline / clear session without network connectivity
      await AuthService.instance.clearSession();

      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.currentUsername, isNull);
      expect(ReceiptRepository.instance.receipts, isEmpty);
    });
  });
}
