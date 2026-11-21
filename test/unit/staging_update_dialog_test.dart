// File: test/unit/staging_update_dialog_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:reciept_logging/domain/models/staging_manifest.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/core/widgets/staging_update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('StagingUpdateDialog Widget Tests', () {
    const testManifest = StagingManifest(
      stage: 'Alpha',
      channel: 'staging',
      version: '1.0.1',
      buildNumber: 15,
      versionDisplay: '1.0.1.0.15',
      downloadUrl: 'http://100.64.0.1:8085/builds/app.apk',
      releaseNotes: 'Fixed navigation delay and added Google sign-in.',
    );

    testWidgets('Renders version tag, release notes, and action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
          const StagingUpdateDialog(manifest: testManifest)));
      await tester.pumpAndSettle();

      expect(find.text('New Version Available'), findsOneWidget);
      expect(find.text('v1.0.1.0.15'), findsOneWidget);
      expect(find.text('Fixed navigation delay and added Google sign-in.'),
          findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update & Install'), findsOneWidget);
    });
  });
}
