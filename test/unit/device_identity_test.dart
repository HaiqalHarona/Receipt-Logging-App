import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/services/device_identity_service.dart';
import 'package:reciept_logging/services/api/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdentityService & ApiConfig Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
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

      expect(headers['X-Device-ID'], equals('dev_persistent_test_uuid_123'));
      expect(headers['X-Device-Token'], equals('token_secret_xyz_456'));
      expect(headers['Content-Type'], equals('application/json'));
    });
  });
}
