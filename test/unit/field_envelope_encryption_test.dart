// test/unit/field_envelope_encryption_test.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/data/models/chat_message_isar.dart';
import 'package:reciept_logging/data/models/conversation_isar.dart';
import 'package:reciept_logging/data/models/receipt_isar.dart';
import 'package:reciept_logging/services/crypto_service.dart';

class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.containsKey(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CryptoService cryptoService;
  late MockSecureStorage mockStorage;

  setUp(() async {
    mockStorage = MockSecureStorage();
    cryptoService = CryptoService.instance;
    cryptoService.resetForTesting(customStorage: mockStorage);
    await cryptoService.init();
  });

  group('Field-Level Envelope Encryption Tests (Section 2.3 & ADV-30-01)', () {
    test('ReceiptIsarModel.rawText envelope encryption and decryption round-trip',
        () async {
      const sensitiveOcrText = 'TAX INVOICE\nMerchant: Starbucks\nTotal: \$45.99\nCard: ****1234';
      final receiptModel = ReceiptIsarModel()
        ..receiptId = 'rcpt_100'
        ..merchant = 'Starbucks'
        ..date = '2026-11-12'
        ..totalAmount = 45.99
        ..currency = 'SGD'
        ..category = 'Food & Dining'
        ..rawText = sensitiveOcrText;

      // Encrypt sensitive fields
      await receiptModel.encryptSensitiveFields(cryptoService);

      expect(receiptModel.rawText, isNotNull);
      expect(receiptModel.rawText!.startsWith('enc:v1:'), isTrue);
      expect(receiptModel.rawText, isNot(contains('Starbucks')));
      expect(receiptModel.rawText, isNot(contains('45.99')));

      // Decrypt sensitive fields
      await receiptModel.decryptSensitiveFields(cryptoService);
      expect(receiptModel.rawText, equals(sensitiveOcrText));
    });

    test('ChatMessageIsarModel.content envelope encryption and decryption round-trip',
        () async {
      const sensitiveContent = 'What were my total expenses on medical supplies last month?';
      final chatModel = ChatMessageIsarModel()
        ..messageId = 'msg_100'
        ..conversationId = 'conv_100'
        ..sender = 'user'
        ..content = sensitiveContent;

      await chatModel.encryptSensitiveFields(cryptoService);

      expect(chatModel.content.startsWith('enc:v1:'), isTrue);
      expect(chatModel.content, isNot(contains('medical')));
      expect(chatModel.content, isNot(contains('expenses')));

      await chatModel.decryptSensitiveFields(cryptoService);
      expect(chatModel.content, equals(sensitiveContent));
    });

    test('ConversationIsarModel.title envelope encryption and decryption round-trip',
        () async {
      const sensitiveTitle = 'Q3 Medical & Tax Audit Discussions';
      final convModel = ConversationIsarModel()
        ..conversationId = 'conv_100'
        ..title = sensitiveTitle;

      await convModel.encryptSensitiveFields(cryptoService);

      expect(convModel.title.startsWith('enc:v1:'), isTrue);
      expect(convModel.title, isNot(contains('Medical')));
      expect(convModel.title, isNot(contains('Audit')));

      await convModel.decryptSensitiveFields(cryptoService);
      expect(convModel.title, equals(sensitiveTitle));
    });

    test('Idempotence: calling encryptSensitiveFields multiple times preserves single envelope',
        () async {
      final chatModel = ChatMessageIsarModel()
        ..messageId = 'msg_idempotent'
        ..conversationId = 'conv_100'
        ..sender = 'user'
        ..content = 'Confidential message';

      await chatModel.encryptSensitiveFields(cryptoService);
      final envelope1 = chatModel.content;
      expect(envelope1.startsWith('enc:v1:'), isTrue);

      // Second encrypt should detect 'enc:v1:' prefix and not re-encrypt
      await chatModel.encryptSensitiveFields(cryptoService);
      expect(chatModel.content, equals(envelope1));

      // Decrypt should yield original message
      await chatModel.decryptSensitiveFields(cryptoService);
      expect(chatModel.content, equals('Confidential message'));
    });

    test('Backward compatibility: decrypting legacy unencrypted plaintext leaves it unchanged',
        () async {
      const legacyPlaintext = 'Legacy Plaintext Message Prior to Migration';
      final chatModel = ChatMessageIsarModel()
        ..messageId = 'msg_legacy'
        ..conversationId = 'conv_100'
        ..sender = 'user'
        ..content = legacyPlaintext;

      // Without encryption, decryptSensitiveFields should leave it intact
      await chatModel.decryptSensitiveFields(cryptoService);
      expect(chatModel.content, equals(legacyPlaintext));
    });
  });
}
