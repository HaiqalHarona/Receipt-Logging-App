import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cryptographic service providing authenticated encryption/decryption (AES-256-GCM)
/// with secure key persistence via [FlutterSecureStorage] and transparent backward-compatible
/// hybrid fallback for legacy plaintext and unencrypted JSON records.
class CryptoService {
  CryptoService._internal({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Shared singleton instance.
  static final CryptoService instance = CryptoService._internal();

  /// Key name used in secure storage.
  static const String masterKeyStorageKey = 'master_data_encryption_key';

  /// Android secure storage options using EncryptedSharedPreferences.
  static const AndroidOptions defaultAndroidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// iOS secure storage options with keychain accessibility.
  static const IOSOptions defaultIosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  FlutterSecureStorage _storage;
  final AesGcm _algorithm = AesGcm.with256bits(nonceLength: 12);

  SecretKey? _masterSecretKey;
  bool _isInitialized = false;

  /// Whether the cryptographic service has initialized its master key.
  bool get isInitialized => _isInitialized;

  /// Internal getter for the master secret key (used for tests or export).
  @visibleForTesting
  SecretKey? get masterSecretKey => _masterSecretKey;

  /// Resets the internal state and optionally configures custom storage/keys for testing.
  @visibleForTesting
  void resetForTesting({
    FlutterSecureStorage? customStorage,
    List<int>? rawKey,
  }) {
    _storage = customStorage ?? const FlutterSecureStorage();
    if (rawKey != null) {
      _masterSecretKey = SecretKey(rawKey);
      _isInitialized = true;
    } else {
      _masterSecretKey = null;
      _isInitialized = false;
    }
  }

  /// Initializes the 256-bit master encryption key from [FlutterSecureStorage],
  /// generating and saving a new CSPRNG key if one does not exist.
  ///
  /// Falls back gracefully to an in-memory key if secure storage is unavailable
  /// (e.g. in test or headless environments).
  Future<void> init() async {
    if (_isInitialized && _masterSecretKey != null) {
      return;
    }

    try {
      final storedKeyBase64 = await _storage.read(
        key: masterKeyStorageKey,
        aOptions: defaultAndroidOptions,
        iOptions: defaultIosOptions,
      );

      if (storedKeyBase64 != null && storedKeyBase64.isNotEmpty) {
        final keyBytes = base64Decode(storedKeyBase64);
        if (keyBytes.length == 32) {
          _masterSecretKey = SecretKey(keyBytes);
          _isInitialized = true;
          return;
        }
      }

      // Generate a new 256-bit (32-byte) key
      final newKeyBytes = _generateSecureRandomBytes(32);
      final newKeyBase64 = base64Encode(newKeyBytes);

      try {
        await _storage.write(
          key: masterKeyStorageKey,
          value: newKeyBase64,
          aOptions: defaultAndroidOptions,
          iOptions: defaultIosOptions,
        );
      } catch (writeError) {
        // Storage write failed (e.g. mocked/headless environment without native channels)
        if (kDebugMode) {
          debugPrint(
              'CryptoService: secure storage write skipped/failed: $writeError');
        }
      }

      _masterSecretKey = SecretKey(newKeyBytes);
      _isInitialized = true;
    } catch (e) {
      // Secure storage read failed or not supported in test environment
      if (kDebugMode) {
        debugPrint(
            'CryptoService: secure storage read failed, falling back to in-memory key: $e');
      }
      if (_masterSecretKey == null) {
        final fallbackKey = _generateSecureRandomBytes(32);
        _masterSecretKey = SecretKey(fallbackKey);
      }
      _isInitialized = true;
    }
  }

  /// Encrypts UTF-8 plain text using AES-256-GCM.
  ///
  /// Returns an envelope string formatted as: `enc:v1:<iv_b64>:<tag_b64>:<ct_b64>`.
  Future<String> encryptText(String text) async {
    await _ensureInitialized();

    final plainBytes = utf8.encode(text);
    final secretBox = await _algorithm.encrypt(
      plainBytes,
      secretKey: _masterSecretKey!,
    );

    final ivB64 = base64Encode(secretBox.nonce);
    final tagB64 = base64Encode(secretBox.mac.bytes);
    final ctB64 = base64Encode(secretBox.cipherText);

    return 'enc:v1:$ivB64:$tagB64:$ctB64';
  }

  /// Decrypts an envelope formatted as `enc:v1:<iv_b64>:<tag_b64>:<ct_b64>`.
  ///
  /// Provides backward-compatible transparent hybrid fallback:
  /// If [envelope] does not start with `enc:v1:`, it is returned unchanged as legacy plaintext.
  Future<String> decryptText(String envelope) async {
    await _ensureInitialized();

    if (!envelope.startsWith('enc:v1:')) {
      // Backward-compatible transparent fallback for legacy plaintext
      return envelope;
    }

    final parts = envelope.split(':');
    if (parts.length != 5 || parts[0] != 'enc' || parts[1] != 'v1') {
      throw const FormatException('Invalid encrypted envelope format');
    }

    final iv = base64Decode(parts[2]);
    final tag = base64Decode(parts[3]);
    final cipherText = base64Decode(parts[4]);

    final secretBox = SecretBox(
      cipherText,
      nonce: iv,
      mac: Mac(tag),
    );

    final decryptedBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: _masterSecretKey!,
    );

    return utf8.decode(decryptedBytes);
  }

  /// Encrypts a JSON-serializable Map using AES-256-GCM.
  ///
  /// Returns an encrypted envelope Map formatted as:
  /// `{"_enc": "v1", "iv": "<iv_b64>", "tag": "<tag_b64>", "data": "<ct_b64>"}`.
  Future<Map<String, dynamic>> encryptJson(Map<String, dynamic> data) async {
    await _ensureInitialized();

    final jsonString = jsonEncode(data);
    final plainBytes = utf8.encode(jsonString);

    final secretBox = await _algorithm.encrypt(
      plainBytes,
      secretKey: _masterSecretKey!,
    );

    return <String, dynamic>{
      '_enc': 'v1',
      'iv': base64Encode(secretBox.nonce),
      'tag': base64Encode(secretBox.mac.bytes),
      'data': base64Encode(secretBox.cipherText),
    };
  }

  /// Decrypts a JSON payload formatted as `{"_enc": "v1", "iv": "...", "tag": "...", "data": "..."}`.
  ///
  /// Provides backward-compatible transparent hybrid fallback:
  /// If [payload] is not an encrypted envelope, it is returned unchanged as legacy JSON.
  Future<Map<String, dynamic>> decryptJson(Map<String, dynamic> payload) async {
    await _ensureInitialized();

    if (payload['_enc'] != 'v1' ||
        !payload.containsKey('iv') ||
        !payload.containsKey('tag') ||
        !payload.containsKey('data')) {
      // Backward-compatible transparent fallback for legacy unencrypted JSON
      return payload;
    }

    final iv = base64Decode(payload['iv'] as String);
    final tag = base64Decode(payload['tag'] as String);
    final cipherText = base64Decode(payload['data'] as String);

    final secretBox = SecretBox(
      cipherText,
      nonce: iv,
      mac: Mac(tag),
    );

    final decryptedBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: _masterSecretKey!,
    );

    final jsonString = utf8.decode(decryptedBytes);
    final decoded = jsonDecode(jsonString);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Encrypts raw binary bytes using AES-256-GCM with authenticated header envelope.
  Future<List<int>> encryptBytes(List<int> plainBytes) async {
    await _ensureInitialized();

    final secretBox = await _algorithm.encrypt(
      plainBytes,
      secretKey: _masterSecretKey!,
    );

    // Prefix with magic header: 4 bytes (ENC\x01), 12 bytes nonce, 16 bytes MAC tag, then ciphertext
    return <int>[
      0x45,
      0x4E,
      0x43,
      0x01,
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ];
  }

  /// Decrypts raw binary bytes encrypted with [encryptBytes].
  /// Provides backward-compatible transparent fallback for legacy plaintext data.
  Future<List<int>> decryptBytes(List<int> data) async {
    await _ensureInitialized();

    if (data.length < 32 ||
        data[0] != 0x45 ||
        data[1] != 0x4E ||
        data[2] != 0x43 ||
        data[3] != 0x01) {
      // Legacy plaintext data
      return data;
    }

    final nonce = data.sublist(4, 16);
    final macBytes = data.sublist(16, 32);
    final cipherText = data.sublist(32);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    return await _algorithm.decrypt(
      secretBox,
      secretKey: _masterSecretKey!,
    );
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized || _masterSecretKey == null) {
      await init();
    }
  }

  List<int> _generateSecureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
