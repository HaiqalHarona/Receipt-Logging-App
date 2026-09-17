import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/services/device_identity_service.dart';
import 'package:reciept_logging/services/api/api_config.dart';

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdentityService & ApiConfig Persistence Tests', () {
    late FakeFlutterSecureStorage fakeStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeStorage = FakeFlutterSecureStorage();
      DeviceIdentityService.instance.setSecureStorageForTesting(fakeStorage);
    });

    test('deviceId and deviceToken are persistent across service calls',
        () async {
      final service = DeviceIdentityService.instance;
      service.setCredentials(
        deviceId: 'dev_persistent_test_uuid_123',
        deviceToken: 'token_secret_xyz_456',
      );

      expect(service.deviceId, equals('dev_persistent_test_uuid_123'));
      expect(service.deviceToken, equals('token_secret_xyz_456'));
      expect(ApiConfig.deviceId, equals('dev_persistent_test_uuid_123'));
      expect(ApiConfig.deviceToken, equals('token_secret_xyz_456'));

      final headers = ApiConfig.buildHeaders(
        deviceId: ApiConfig.deviceId,
        deviceToken: ApiConfig.deviceToken,
      );

      expect(headers['X-Device-Name'], equals('dev_persistent_test_uuid_123'));
      expect(headers['X-Device-Token'], equals('token_secret_xyz_456'));
      expect(headers['Content-Type'], equals('application/json'));
    });

    test('markTrialUsed persists across simulated app reinstallation via secure storage',
        () async {
      final service = DeviceIdentityService.instance;
      expect(service.hasDeviceUsedTrial, isFalse);

      await service.markTrialUsed();
      expect(service.hasDeviceUsedTrial, isTrue);

      // Verify written to both SharedPreferences and SecureStorage
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app_has_device_used_trial'), isTrue);
      expect(await fakeStorage.read(key: 'app_has_device_used_trial'), equals('true'));

      // Simulate app uninstallation: SharedPreferences is wiped
      await prefs.clear();
      expect(prefs.getBool('app_has_device_used_trial'), isNull);

      // But SecureStorage (Keychain/Keystore) survives app reinstall!
      expect(await fakeStorage.read(key: 'app_has_device_used_trial'), equals('true'));
    });
  });
}
