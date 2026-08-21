import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/data/repositories/conversation_repository.dart';
import 'package:reciept_logging/data/repositories/chat_message_repository.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/ui/features/dashboard/view_models/dashboard_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.clearSession();
  });

  tearDown(() async {
    await AuthService.instance.clearSession();
  });

  group('Unauthenticated State & User Data Isolation Tests', () {
    test('Unauthenticated guest cannot see cloud user conversations in ConversationRepository', () async {
      // Setup: ensure logged out
      expect(AuthService.instance.isLoggedIn, isFalse);

      // Create a cloud conversation with UUID (simulating previous user session record)
      const cloudConvId = '12345678-1234-1234-1234-1234567890ab';
      await ConversationRepository.instance.createConversation(
        id: cloudConvId,
        title: 'Secret Test User Chat',
      );

      // Also create a local guest conversation
      final guestConv = await ConversationRepository.instance.createConversation(
        id: 'local_123456',
        title: 'Guest Inquiry',
      );

      // Verify: ConversationRepository.conversations only exposes non-UUID guest chats to unauthenticated users
      final activeConvs = ConversationRepository.instance.conversations;
      expect(activeConvs.any((c) => c.id == cloudConvId), isFalse);
      expect(activeConvs.any((c) => c.id == guestConv.id), isTrue);
    });

    test('Unauthenticated guest cannot see cloud receipts in ReceiptRepository', () async {
      // Setup: ensure logged out
      expect(AuthService.instance.isLoggedIn, isFalse);

      const cloudReceipt = Receipt(
        id: 'abcdef01-2345-6789-abcd-ef0123456789',
        merchant: 'Cloud Test Merchant',
        date: 'Aug 21, 2026',
        amount: 250.00,
        currency: 'USD',
        category: 'Electronics',
      );

      const guestReceipt = Receipt(
        id: 'local_receipt_101',
        merchant: 'Guest Coffee Shop',
        date: 'Aug 21, 2026',
        amount: 4.50,
        currency: 'USD',
        category: 'Dining',
      );

      await ReceiptRepository.instance.saveReceipt(cloudReceipt);
      await ReceiptRepository.instance.saveReceipt(guestReceipt);

      // Verify: ReceiptRepository.receipts filters out cloud UUID receipts when unauthenticated
      final visibleReceipts = ReceiptRepository.instance.receipts;
      expect(visibleReceipts.any((r) => r.id == cloudReceipt.id), isFalse);
      expect(visibleReceipts.any((r) => r.id == guestReceipt.id), isTrue);
    });

    test('AuthService.init in unauthenticated state sanitizes profile and keeps auth null', () async {
      // Mock SharedPreferences with empty session
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.init();

      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.currentUserId, isNull);
      expect(AuthService.instance.currentUsername, isNull);
      expect(AuthService.instance.currentUserToken, isNull);
      expect(AuthService.instance.cachedProfile, isNull);
    });

    test('DashboardViewModel reacts to login and logout without lingering user traces', () async {
      final viewModel = DashboardViewModel();
      expect(viewModel.isLoggedIn, isFalse);
      expect(viewModel.username, isNull);

      // Log in
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr-isolation-123',
        username: 'TestUserIso',
        email: 'iso@example.com',
        createdAt: '2026-08-21T00:00:00Z',
      ));

      expect(viewModel.isLoggedIn, isTrue);
      expect(viewModel.username, equals('TestUserIso'));

      // Log out
      await AuthService.instance.clearSession();

      expect(viewModel.isLoggedIn, isFalse);
      expect(viewModel.username, isNull);
      expect(viewModel.avatarImagePath, isNull);

      viewModel.dispose();
    });

    test('Logging in exposes cloud conversations, and logging out removes all records', () async {
      // 1. Log in
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr-flow-999',
        username: 'FlowUser',
        email: 'flow@example.com',
        createdAt: '2026-08-21T00:00:00Z',
      ));
      expect(AuthService.instance.isLoggedIn, isTrue);

      const convUuid = '98765432-4321-4321-4321-210987654321';
      await ConversationRepository.instance.createConversation(
        id: convUuid,
        title: 'Authenticated Chat Flow',
      );

      // Authenticated user can see their cloud conversations
      expect(ConversationRepository.instance.conversations.any((c) => c.id == convUuid), isTrue);

      // 2. Log out
      await AuthService.instance.clearSession();

      // After logout, session is gone and repositories are fully cleared
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(ConversationRepository.instance.conversations, isEmpty);
      expect(ReceiptRepository.instance.receipts, isEmpty);
      expect(ChatMessageRepository.instance.currentHistory, isEmpty);
    });
  });
}
