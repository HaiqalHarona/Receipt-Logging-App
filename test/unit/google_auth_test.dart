import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/ui/features/auth/widgets/google_sign_in_button.dart';
import 'package:reciept_logging/ui/features/auth/widgets/google_username_prompt_sheet.dart';

void main() {
  group('Google Authentication Tests', () {
    test('UserRecordDto parses google_id correctly in fromJson and toJson', () {
      final json = {
        'id': 'test-uuid-1234',
        'username': 'john_doe',
        'email': 'john@gmail.com',
        'google_id': '108203948572019485721',
        'created_at': '2026-09-29T00:00:00Z',
        'tier': 'free',
      };

      final dto = UserRecordDto.fromJson(json);
      expect(dto.id, equals('test-uuid-1234'));
      expect(dto.username, equals('john_doe'));
      expect(dto.email, equals('john@gmail.com'));
      expect(dto.googleId, equals('108203948572019485721'));

      final outJson = dto.toJson();
      expect(outJson['google_id'], equals('108203948572019485721'));
    });

    testWidgets('GoogleSignInButton renders label and triggers callback on tap',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              label: 'Continue with Google',
              onPressed: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('GoogleSignInButton shows spinner when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              label: 'Continue with Google',
              isLoading: true,
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('GoogleUsernamePromptSheet validates username length and format',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleUsernamePromptSheet(
              suggestedUsername: '',
              email: 'alice@gmail.com',
            ),
          ),
        ),
      );

      expect(find.text('Choose a Username'), findsOneWidget);

      // Attempt to submit empty username
      await tester.tap(find.text('Complete Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Username cannot be empty.'), findsOneWidget);

      // Enter too short username
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.tap(find.text('Complete Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Username must be between 3 and 10 characters.'),
          findsOneWidget);

      // Enter invalid character
      await tester.enterText(find.byType(TextField), 'ab@c');
      await tester.tap(find.text('Complete Sign Up'));
      await tester.pumpAndSettle();
      expect(
          find.text('Letters, numbers, and underscores only.'), findsOneWidget);
    });
  });
}
