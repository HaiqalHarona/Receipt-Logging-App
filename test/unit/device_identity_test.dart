import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/api/backend_api_client.dart';
import 'package:reciept_logging/cloud/models/device_models.dart';
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

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

class TrackingBackendApiClient extends BackendApiClient {
  TrackingBackendApiClient() : super(httpClient: http.Client());

  String? registeredDeviceId;
  String? registeredDeviceToken;
  int registerDeviceCallCount = 0;

  @override
  Future<DeviceRecordDto> registerDevice({
    required String deviceId,
    required String deviceToken,
  }) async {
    registerDeviceCallCount++;
    registeredDeviceId = deviceId;
    registeredDeviceToken = deviceToken;
    return DeviceRecordDto(
      id: 'rec_123',
      deviceId: deviceId,
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdentityService & ApiConfig Persistence Tests', () {
    late FakeFlutterSecureStorage fakeStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeStorage = FakeFlutterSecureStorage();
      DeviceIdentityService.instance.resetForTesting();
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

    test('resetAndRegenerateCredentials generates new UUIDs, saves them, and calls registerDevice',
        () async {
      final service = DeviceIdentityService.instance;
      final trackingClient = TrackingBackendApiClient();

      await service.resetAndRegenerateCredentials(trackingClient);

      expect(service.deviceId.startsWith('dev_'), isTrue);
      expect(service.deviceToken.startsWith('token_'), isTrue);
      expect(service.deviceId.contains('dev_fixed_debug_device'), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_device_id'), equals(service.deviceId));
      expect(prefs.getString('app_device_token'), equals(service.deviceToken));
      expect(await fakeStorage.read(key: 'app_device_id'), equals(service.deviceId));
      expect(await fakeStorage.read(key: 'app_device_token'), equals(service.deviceToken));

      expect(trackingClient.registerDeviceCallCount, equals(1));
      expect(trackingClient.registeredDeviceId, equals(service.deviceId));
      expect(trackingClient.registeredDeviceToken, equals(service.deviceToken));
    });

    test('init() purges stale dev_fixed_debug_device credentials and generates fresh ones',
        () async {
      final service = DeviceIdentityService.instance;
      final trackingClient = TrackingBackendApiClient();

      // Seed SharedPreferences and SecureStorage with stale fixed dev credentials
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_device_id', 'dev_fixed_debug_device_001');
      await prefs.setString('app_device_token', 'token_fixed_debug_secret_001');
      await fakeStorage.write(key: 'app_device_id', value: 'dev_fixed_debug_device_001');
      await fakeStorage.write(key: 'app_device_token', value: 'token_fixed_debug_secret_001');

      await service.init(trackingClient);

      // Verify stale fixed ID was NOT used
      expect(service.deviceId.startsWith('dev_fixed_debug_device'), isFalse);
      expect(service.deviceId.startsWith('dev_'), isTrue);
      expect(service.deviceToken.startsWith('token_fixed_debug'), isFalse);
      expect(service.deviceToken.startsWith('token_'), isTrue);

      // Verify persisted fresh credentials
      expect(prefs.getString('app_device_id'), equals(service.deviceId));
      expect(prefs.getString('app_device_token'), equals(service.deviceToken));
      expect(await fakeStorage.read(key: 'app_device_id'), equals(service.deviceId));
      expect(await fakeStorage.read(key: 'app_device_token'), equals(service.deviceToken));
    });

    test('BackendApiClient transparently self-heals when guest request receives 401 invalid token',
        () async {
      int requestCount = 0;
      final receivedDeviceTokens = <String>[];

      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/devices/register')) {
          return http.Response(
            jsonEncode({
              'id': 'rec_healed_001',
              'device_id': 'dev_healed_001',
              'created_at': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('/devices/me')) {
          requestCount++;
          final token = request.headers['X-Device-Token'] ?? '';
          receivedDeviceTokens.add(token);

          if (requestCount == 1) {
            // First attempt rejected with 401 Invalid device authentication token
            return http.Response(
              jsonEncode({'detail': 'Invalid device authentication token.'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }

          // Second attempt succeeds
          return http.Response(
            jsonEncode({
              'id': 'rec_healed_002',
              'device_id': request.headers['X-Device-Name'] ?? '',
              'created_at': DateTime.now().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final client = BackendApiClient(httpClient: mockHttp);
      DeviceIdentityService.instance.setCredentials(
        deviceId: 'dev_desynced_old_id',
        deviceToken: 'token_desynced_old_secret',
      );

      final profile = await client.fetchDeviceProfile(
        deviceId: 'dev_desynced_old_id',
        deviceToken: 'token_desynced_old_secret',
      );

      expect(requestCount, equals(2));
      expect(profile.deviceId, equals(DeviceIdentityService.instance.deviceId));
      expect(receivedDeviceTokens.length, equals(2));
      expect(receivedDeviceTokens[0], equals('token_desynced_old_secret'));
      expect(receivedDeviceTokens[1].startsWith('token_'), isTrue);
      expect(receivedDeviceTokens[1], isNot(equals('token_desynced_old_secret')));
    });

    test('BackendApiClient transparently self-heals in parseManyReceiptImages on guest 401',
        () async {
      int scanAttemptCount = 0;
      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/devices/register')) {
          return http.Response(
            jsonEncode({
              'id': 'rec_healed_reg',
              'device_id': 'dev_healed_reg',
              'created_at': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('/scan/parse-many')) {
          scanAttemptCount++;
          if (scanAttemptCount == 1) {
            return http.Response(
              jsonEncode({'detail': 'Invalid device authentication token.'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response(
            jsonEncode({
              'batch_id': 'batch_healed_123',
              'status': 'queued',
              'item_count': 1,
              'created_at': DateTime.now().toIso8601String(),
            }),
            202,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final client = BackendApiClient(httpClient: mockHttp);
      DeviceIdentityService.instance.setCredentials(
        deviceId: 'dev_desynced_scan_id',
        deviceToken: 'token_desynced_scan_secret',
      );

      final res = await client.parseManyReceiptImages(
        imageFiles: [
          (bytes: [1, 2, 3], filename: 'test.jpg'),
        ],
        requestType: 'guest',
        deviceName: 'dev_desynced_scan_id',
        deviceToken: 'token_desynced_scan_secret',
      );

      expect(scanAttemptCount, equals(2));
      expect(res.batchId, equals('batch_healed_123'));
    });
  });
}
