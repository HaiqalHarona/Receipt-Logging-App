import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/services/crypto_service.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

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
      _storage[key] = value;
    } else {
      _storage.remove(key);
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
  }) async {
    return _storage.containsKey(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CryptoService cryptoService;
  late FakeFlutterSecureStorage fakeStorage;

  setUp(() async {
    fakeStorage = FakeFlutterSecureStorage();
    cryptoService = CryptoService.instance;
    cryptoService.resetForTesting(customStorage: fakeStorage);
  });

  group('CryptoService Initialization & Key Management', () {
    test('init() generates a 256-bit key and stores it in secure storage',
        () async {
      expect(cryptoService.isInitialized, isFalse);

      await cryptoService.init();

      expect(cryptoService.isInitialized, isTrue);
      expect(cryptoService.masterSecretKey, isNotNull);

      final keyBytes = await cryptoService.masterSecretKey!.extractBytes();
      expect(keyBytes.length, equals(32)); // 256 bits = 32 bytes

      // Verify it was persisted to storage
      final storedKeyBase64 = await fakeStorage.read(
        key: CryptoService.masterKeyStorageKey,
      );
      expect(storedKeyBase64, isNotNull);
      final storedKey = storedKeyBase64!;
      expect(base64Decode(storedKey).length, equals(32));
      expect(base64Decode(storedKey), equals(keyBytes));
    });

    test('init() reuses existing key from secure storage if present', () async {
      // Pre-seed storage with a known 32-byte key
      final testKeyBytes = List<int>.generate(32, (i) => (i * 7) % 256);
      final testKeyBase64 = base64Encode(testKeyBytes);
      await fakeStorage.write(
        key: CryptoService.masterKeyStorageKey,
        value: testKeyBase64,
      );

      await cryptoService.init();

      expect(cryptoService.isInitialized, isTrue);
      final keyBytes = await cryptoService.masterSecretKey!.extractBytes();
      expect(keyBytes, equals(testKeyBytes));
    });

    test('init() handles in-memory fallback gracefully when storage throws',
        () async {
      // Create a broken storage that throws
      final brokenStorage = _ThrowingSecureStorage();
      cryptoService.resetForTesting(customStorage: brokenStorage);

      await cryptoService.init();

      expect(cryptoService.isInitialized, isTrue);
      expect(cryptoService.masterSecretKey, isNotNull);
      final keyBytes = await cryptoService.masterSecretKey!.extractBytes();
      expect(keyBytes.length, equals(32));
    });
  });

  group('Text Encryption & Decryption (AES-256-GCM)', () {
    test('encryptText produces standard envelope enc:v1:<iv>:<tag>:<ct>',
        () async {
      await cryptoService.init();

      const plainText = 'Receipt: \$128.50 at SuperMart on 2026-08-24';
      final envelope = await cryptoService.encryptText(plainText);

      expect(envelope.startsWith('enc:v1:'), isTrue);
      final parts = envelope.split(':');
      expect(parts.length, equals(5));
      expect(parts[0], equals('enc'));
      expect(parts[1], equals('v1'));

      final ivBytes = base64Decode(parts[2]);
      final tagBytes = base64Decode(parts[3]);
      final ctBytes = base64Decode(parts[4]);

      expect(ivBytes.length, equals(12)); // 12-byte CSPRNG nonce
      expect(tagBytes.length, equals(16)); // 16-byte MAC tag
      expect(ctBytes.isNotEmpty, isTrue);
    });

    test('encryptText and decryptText round-trip successfully', () async {
      await cryptoService.init();

      final testCases = [
        'Short string',
        '',
        'Special characters: !@#\$%^&*()_+-=[]{}|;:,.<>?/~`',
        'Unicode & Emojis: 🧾 Total: 100€ ☕ Café & 🍣 Sushi 漢字',
        'A' * 5000, // Large text
      ];

      for (final text in testCases) {
        final encrypted = await cryptoService.encryptText(text);
        expect(encrypted, isNot(equals(text)));

        final decrypted = await cryptoService.decryptText(encrypted);
        expect(decrypted, equals(text));
      }
    });

    test('encryptText produces unique nonces and ciphertexts for same input',
        () async {
      await cryptoService.init();

      const message = 'Confidential receipt metadata';
      final enc1 = await cryptoService.encryptText(message);
      final enc2 = await cryptoService.encryptText(message);

      expect(enc1, isNot(equals(enc2)));

      expect(await cryptoService.decryptText(enc1), equals(message));
      expect(await cryptoService.decryptText(enc2), equals(message));
    });

    test('decryptText rejects tampered ciphertext or MAC tag', () async {
      await cryptoService.init();

      const plainText = 'Sensitive financial transaction';
      final envelope = await cryptoService.encryptText(plainText);
      final parts = envelope.split(':');

      // 1. Tamper ciphertext
      final ctBytes = base64Decode(parts[4]);
      ctBytes[0] ^= 0xFF; // Flip bits in ciphertext
      final tamperedCtEnvelope =
          'enc:v1:${parts[2]}:${parts[3]}:${base64Encode(ctBytes)}';

      expect(
        () async => await cryptoService.decryptText(tamperedCtEnvelope),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      // 2. Tamper MAC tag
      final tagBytes = base64Decode(parts[3]);
      tagBytes[0] ^= 0x01; // Flip bit in auth tag
      final tamperedTagEnvelope =
          'enc:v1:${parts[2]}:${base64Encode(tagBytes)}:${parts[4]}';

      expect(
        () async => await cryptoService.decryptText(tamperedTagEnvelope),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      // 3. Tamper IV
      final ivBytes = base64Decode(parts[2]);
      ivBytes[0] ^= 0x01;
      final tamperedIvEnvelope =
          'enc:v1:${base64Encode(ivBytes)}:${parts[3]}:${parts[4]}';

      expect(
        () async => await cryptoService.decryptText(tamperedIvEnvelope),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('decryptText throws FormatException on malformed envelope structure',
        () async {
      await cryptoService.init();

      expect(
        () async => await cryptoService.decryptText('enc:v1:not-enough-parts'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () async => await cryptoService.decryptText('enc:v1:a:b:c:d'),
        throwsA(isA<FormatException>()),
      );
    });

    test('decryptText transparently falls back for legacy unencrypted text',
        () async {
      await cryptoService.init();

      const legacyPlainText1 =
          'Standard plaintext note from legacy app version';
      const legacyPlainText2 = '{"legacy": "json_string_unencrypted"}';
      const legacyPlainText3 =
          'Some words containing enc:v2: or similar non-v1 tags';

      expect(await cryptoService.decryptText(legacyPlainText1),
          equals(legacyPlainText1));
      expect(await cryptoService.decryptText(legacyPlainText2),
          equals(legacyPlainText2));
      expect(await cryptoService.decryptText(legacyPlainText3),
          equals(legacyPlainText3));
    });
  });

  group('JSON Map Encryption & Decryption (AES-256-GCM)', () {
    test('encryptJson produces envelope map with _enc: v1, iv, tag, and data',
        () async {
      await cryptoService.init();

      final data = {
        'id': 'rec_12345',
        'merchant': 'Apple Store',
        'total': 1299.99,
        'tax': 104.00,
        'items': [
          {'name': 'MacBook Pro', 'price': 1299.99, 'quantity': 1}
        ],
        'verified': true,
        'nullField': null,
      };

      final encrypted = await cryptoService.encryptJson(data);

      expect(encrypted['_enc'], equals('v1'));
      expect(encrypted.containsKey('iv'), isTrue);
      expect(encrypted.containsKey('tag'), isTrue);
      expect(encrypted.containsKey('data'), isTrue);

      final ivBytes = base64Decode(encrypted['iv'] as String);
      final tagBytes = base64Decode(encrypted['tag'] as String);
      final dataBytes = base64Decode(encrypted['data'] as String);

      expect(ivBytes.length, equals(12));
      expect(tagBytes.length, equals(16));
      expect(dataBytes.isNotEmpty, isTrue);
    });

    test('encryptJson and decryptJson round-trip successfully', () async {
      await cryptoService.init();

      final originalData = <String, dynamic>{
        'receiptId': 'uuid-9876-5432-10',
        'storeName': 'Target & Supermarket',
        'date': '2026-08-24T19:10:00Z',
        'total': 84.75,
        'isBusinessExpense': false,
        'items': [
          {'description': 'Organic Milk', 'qty': 2, 'unitPrice': 4.50},
          {'description': 'Cereal 🥣', 'qty': 1, 'unitPrice': 5.25},
        ],
        'metadata': {
          'category': 'Groceries',
          'confidence': 0.98,
        },
      };

      final encryptedMap = await cryptoService.encryptJson(originalData);
      final decryptedMap = await cryptoService.decryptJson(encryptedMap);

      expect(decryptedMap, equals(originalData));
    });

    test('decryptJson rejects tampered JSON envelope data or tag', () async {
      await cryptoService.init();

      final data = {'secret_token': 'sk_test_123456'};
      final encrypted = await cryptoService.encryptJson(data);

      // Tamper ciphertext
      final ctBytes = base64Decode(encrypted['data'] as String);
      ctBytes[0] ^= 0xFF;
      final tamperedDataPayload = {
        ...encrypted,
        'data': base64Encode(ctBytes),
      };

      expect(
        () async => await cryptoService.decryptJson(tamperedDataPayload),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      // Tamper MAC tag
      final tagBytes = base64Decode(encrypted['tag'] as String);
      tagBytes[0] ^= 0xFF;
      final tamperedTagPayload = {
        ...encrypted,
        'tag': base64Encode(tagBytes),
      };

      expect(
        () async => await cryptoService.decryptJson(tamperedTagPayload),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test(
        'decryptJson transparently falls back for legacy unencrypted JSON maps',
        () async {
      await cryptoService.init();

      final legacyMap1 = {
        'id': 'legacy_rec_001',
        'store': 'Old Supermarket',
        'amount': 15.20,
      };

      final legacyMap2 = {
        '_enc': 'unsupported_version',
        'info': 'should not be decrypted',
      };

      expect(await cryptoService.decryptJson(legacyMap1), equals(legacyMap1));
      expect(await cryptoService.decryptJson(legacyMap2), equals(legacyMap2));
    });
  });
}

class _ThrowingSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('Simulated native platform storage exception');
  }

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
    throw Exception('Simulated native platform storage write exception');
  }
}
