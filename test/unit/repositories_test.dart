import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/domain/models/conversation.dart';
import 'package:reciept_logging/domain/models/chat_message.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/data/mappers/conversation_mapper.dart';
import 'package:reciept_logging/data/mappers/chat_message_mapper.dart';
import 'package:reciept_logging/data/repositories/conversation_repository.dart';
import 'package:reciept_logging/data/repositories/chat_message_repository.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';

void main() {
  group('Clean Architecture Mapper & Domain Equality Tests', () {
    test('Conversation domain equality and mapper round-trip', () {
      final now = DateTime.now();
      final conv = Conversation(
        id: 'conv_123',
        title: 'Original Title',
        createdAt: now,
        updatedAt: now,
      );

      final sameConv = Conversation(
        id: 'conv_123',
        title: 'Original Title',
        createdAt: now,
        updatedAt: now,
      );

      expect(conv, equals(sameConv));
      expect(conv.hashCode, equals(sameConv.hashCode));

      final updated = conv.copyWith(title: 'Updated Title');
      expect(conv == updated, isFalse);

      // Isar mapper round-trip
      final isarModel = conv.toIsar();
      expect(isarModel.conversationId, equals('conv_123'));
      expect(isarModel.toDomain(), equals(conv));

      // DTO mapper round-trip
      final dto = conv.toDto(deviceId: 'dev_456');
      expect(dto.id, equals('conv_123'));
      expect(dto.toDomain().title, equals('Original Title'));
    });

    test('ChatMessage domain equality and mapper round-trip', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg_1',
        conversationId: 'conv_123',
        sender: 'user',
        content: 'Hello AI',
        createdAt: now,
      );

      final sameMsg = ChatMessage(
        id: 'msg_1',
        conversationId: 'conv_123',
        sender: 'user',
        content: 'Hello AI',
        createdAt: now,
      );

      expect(msg, equals(sameMsg));
      expect(msg.hashCode, equals(sameMsg.hashCode));

      final updated = msg.copyWith(content: 'Modified content');
      expect(msg == updated, isFalse);

      // Isar mapper round-trip
      final isarModel = msg.toIsar();
      expect(isarModel.messageId, equals('msg_1'));
      expect(isarModel.toDomain(), equals(msg));

      // DTO mapper round-trip
      final dto = msg.toDto();
      expect(dto.toDomain().content, equals('Hello AI'));
    });

    test('Receipt domain value equality with listEquals', () {
      const receipt1 = Receipt(
        id: 'r_1',
        merchant: 'Target',
        date: '2026-08-04',
        amount: 50.0,
        currency: 'USD',
        category: 'Groceries 🛒',
        items: ['Milk', 'Bread'],
      );

      const receipt2 = Receipt(
        id: 'r_1',
        merchant: 'Target',
        date: '2026-08-04',
        amount: 50.0,
        currency: 'USD',
        category: 'Groceries 🛒',
        items: ['Milk', 'Bread'],
      );

      expect(receipt1, equals(receipt2));
      expect(receipt1.hashCode, equals(receipt2.hashCode));

      final updated = receipt1.copyWith(amount: 55.0);
      expect(receipt1 == updated, isFalse);
    });
  });

  group('Repository Memory Fallback Tests', () {
    test('ReceiptRepository initial sample items and total calculations',
        () async {
      final repo = ReceiptRepository.instance;
      expect(repo.receipts.isNotEmpty, isTrue);

      final totalUSD = repo.calculateTotalSpent('USD');
      expect(totalUSD, greaterThan(0.0));
    });

    test('ConversationRepository memory operations', () async {
      final repo = ConversationRepository.instance;
      final conv = await repo.createConversation(
        id: 'conv_test_1',
        title: 'Test Chat',
      );

      expect(conv.id, equals('conv_test_1'));
      expect(conv.title, equals('Test Chat'));

      await repo.updateTitle('conv_test_1', 'Renamed Chat');
      expect(repo.conversations.first.title, equals('Renamed Chat'));

      await repo.softDeleteConversation('conv_test_1');
      expect(repo.conversations.where((c) => c.id == 'conv_test_1').isEmpty,
          isTrue);
    });

    test('ChatMessageRepository memory operations', () async {
      final repo = ChatMessageRepository.instance;
      await repo.init();

      final msg = await repo.addMessage(
        conversationId: 'conv_test_1',
        sender: 'user',
        content: 'Testing message',
        id: 'msg_test_1',
      );

      expect(msg.id, equals('msg_test_1'));
      expect(msg.content, equals('Testing message'));
      expect(repo.currentHistory.length, equals(1));
    });
  });
}
