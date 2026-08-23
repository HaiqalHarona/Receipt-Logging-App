import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/ui/features/auth/views/login_screen.dart';
import 'package:reciept_logging/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:reciept_logging/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DashboardViewModel Auth State Tests', () {
    late DashboardViewModel viewModel;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.clearSession();
      viewModel = DashboardViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Initial auth state is logged out', () {
      expect(viewModel.isLoggedIn, isFalse);
      expect(viewModel.username, isNull);
      expect(viewModel.avatarImagePath, isNull);
    });

    test('setLoginState updates auth state and triggers notification', () {
      bool notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setLoginState(
        isLoggedIn: true,
        username: 'TestUser',
        avatarImagePath: 'https://example.com/avatar.png',
      );

      expect(viewModel.isLoggedIn, isTrue);
      expect(viewModel.username, equals('TestUser'));
      expect(
          viewModel.avatarImagePath, equals('https://example.com/avatar.png'));
      expect(notified, isTrue);
    });

    test(
        'AuthService clearSession notifies DashboardViewModel and resets auth state',
        () async {
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr-123',
        username: 'LoggedInUser',
        email: 'user@example.com',
        createdAt: '',
      ));

      expect(viewModel.isLoggedIn, isTrue);
      expect(viewModel.username, equals('LoggedInUser'));

      await AuthService.instance.clearSession();

      expect(viewModel.isLoggedIn, isFalse);
      expect(viewModel.username, isNull);
    });
  });

  group('LoginScreen Widget Tests', () {
    Widget buildTestableWidget(Widget child) {
      return NeumorphicApp(
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.darkNeumorphicTheme,
        home: child,
      );
    }

    testWidgets(
        'LoginScreen renders username/password fields, Sign In button, and links',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('USERNAME OR EMAIL'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
      final plainTexts = richTextFinder
          .evaluate()
          .map((e) => (e.widget as RichText).text.toPlainText());
      expect(plainTexts.any((t) => t.contains('Sign Up')), isTrue);
    });

    testWidgets('Forgot Password and Sign Up links are present on LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsOneWidget);

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
      final plainTexts = richTextFinder
          .evaluate()
          .map((e) => (e.widget as RichText).text.toPlainText());
      expect(plainTexts.any((t) => t.contains('Sign Up')), isTrue);
    });
  });

  group('DashboardScreen Header Tests', () {
    Widget buildTestableDashboard() {
      return NeumorphicApp(
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.darkNeumorphicTheme,
        home: const DashboardScreen(),
      );
    }

    testWidgets(
        'DashboardScreen omits Hello Nino placeholder when logged out and shows guest account badge',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(find.text('Hello, Nino'), findsNothing);
      expect(find.text('Here is your spending breakdown'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });
  });
}
