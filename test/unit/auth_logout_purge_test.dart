import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';
import 'package:reciept_logging/data/repositories/conversation_repository.dart';
import 'package:reciept_logging/data/repositories/chat_message_repository.dart';
import 'package:reciept_logging/services/category_service.dart';
import 'package:reciept_logging/domain/models/receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Logout Database & Memory Purge Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.clearSession();
    });

    tearDown(() async {
      await AuthService.instance.clearSession();
    });

    test('clearSession purges all local repositories, categories, and session state', () async {
      // 1. Setup authenticated session
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr_test_logout_123',
        username: 'TestPurgeUser',
        email: 'purge@example.com',
        createdAt: '2026-08-20T12:00:00Z',
      ));
      expect(AuthService.instance.isLoggedIn, isTrue);

      // 2. Populate repositories with active user data
      const sampleReceipt = Receipt(
        id: 'receipt_test_logout',
        merchant: 'Target Store',
        date: 'Aug 20, 2026',
        amount: 45.99,
        currency: 'USD',
        category: 'Shopping',
      );
      await ReceiptRepository.instance.saveReceipt(sampleReceipt);
      expect(ReceiptRepository.instance.receipts.isNotEmpty, isTrue);

      await ConversationRepository.instance.createConversation(
        id: 'conv_test_logout',
        title: 'Logout Test Chat',
      );
      expect(ConversationRepository.instance.conversations.any((c) => c.id == 'conv_test_logout'), isTrue);

      await ChatMessageRepository.instance.init();
      await ChatMessageRepository.instance.addMessage(
        conversationId: 'conv_test_logout',
        sender: 'user',
        content: 'Hello before logout',
        id: 'msg_test_logout',
      );
      expect(ChatMessageRepository.instance.currentHistory.any((m) => m.id == 'msg_test_logout'), isTrue);

      await CategoryService.instance.addCategory('CustomCat', 0xFF10B981, 0xe318);
      expect(CategoryService.instance.customCategories.any((c) => c.name == 'CustomCat'), isTrue);

      // 3. Trigger logout
      await AuthService.instance.clearSession();

      // 4. Assert all repositories and in-memory caches are completely purged
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.currentUsername, isNull);
      expect(AuthService.instance.currentUserToken, isNull);
      expect(AuthService.instance.currentUserId, isNull);

      expect(ReceiptRepository.instance.receipts, isEmpty);
      expect(ConversationRepository.instance.conversations, isEmpty);
      expect(ChatMessageRepository.instance.currentHistory, isEmpty);
      expect(CategoryService.instance.customCategories, isEmpty);
    });
  });
}
