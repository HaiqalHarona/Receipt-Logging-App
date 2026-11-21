// File: test/unit/spending_notification_settings_test.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/services/spending_notification_service.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/features/settings/views/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    try {
      final loc = tz.getLocation('UTC');
      tz.setLocalLocation(loc);
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.clearSession();
    await SpendingNotificationService.instance.init();
    await SpendingNotificationService.instance.setNotificationsEnabled(false);
    await SpendingNotificationService.instance.setWeeklySpendingEnabled(true);
    await SpendingNotificationService.instance.setWeeklyDay(DateTime.monday);
    await SpendingNotificationService.instance.setWeeklyTime(const TimeOfDay(hour: 9, minute: 0));
    await SpendingNotificationService.instance.setMonthlySpendingEnabled(true);
    await SpendingNotificationService.instance.setMonthlyDay(1);
    await SpendingNotificationService.instance.setMonthlyTime(const TimeOfDay(hour: 9, minute: 0));
  });

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: child,
    );
  }

  group('SettingsScreen NOTIFICATIONS Section Widget Tests', () {
    testWidgets('NOTIFICATIONS section header and master toggle render',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      expect(find.text('Spending Notifications'), findsOneWidget);
      expect(find.byKey(const Key('master_notification_switch')), findsOneWidget);

      // When master is OFF, weekly and monthly rows are NOT visible
      expect(find.byKey(const Key('weekly_notification_switch')), findsNothing);
      expect(find.byKey(const Key('monthly_notification_switch')), findsNothing);
    });

    testWidgets('Toggling master switch ON reveals weekly and monthly sections',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Tap master switch
      await tester.tap(find.byKey(const Key('master_notification_switch')));
      await tester.pumpAndSettle();

      expect(SpendingNotificationService.instance.notificationsEnabled, isTrue);

      // Weekly and monthly switches should now be visible
      expect(find.byKey(const Key('weekly_notification_switch')), findsOneWidget);
      expect(find.byKey(const Key('monthly_notification_switch')), findsOneWidget);

      // Schedule rows and test buttons should be visible
      expect(find.byKey(const Key('weekly_schedule_row')), findsOneWidget);
      expect(find.byKey(const Key('test_weekly_notification_btn')), findsOneWidget);
      expect(find.byKey(const Key('monthly_schedule_row')), findsOneWidget);
      expect(find.byKey(const Key('test_monthly_notification_btn')), findsOneWidget);

      // Verify schedule text
      expect(find.textContaining('Every Monday at 09:00 AM'), findsOneWidget);
      expect(find.textContaining('On the 1st of the month at 09:00 AM'), findsOneWidget);
    });

    testWidgets('Tapping weekly schedule row opens weekly bottom sheet with day chips and time',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await SpendingNotificationService.instance.setNotificationsEnabled(true);

      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Tap weekly schedule row
      await tester.tap(find.byKey(const Key('weekly_schedule_row')));
      await tester.pumpAndSettle();

      // Bottom sheet should be open
      expect(find.text('Weekly Spending Schedule'), findsOneWidget);
      expect(find.text('DAY OF WEEK'), findsOneWidget);
      expect(find.byKey(const Key('weekly_day_chip_Mon')), findsOneWidget);
      expect(find.byKey(const Key('weekly_day_chip_Fri')), findsOneWidget);
      expect(find.byKey(const Key('weekly_time_picker_btn')), findsOneWidget);
      expect(find.byKey(const Key('save_weekly_schedule_btn')), findsOneWidget);

      // Select Friday
      await tester.tap(find.byKey(const Key('weekly_day_chip_Fri')));
      await tester.pumpAndSettle();

      // Save schedule
      await tester.tap(find.byKey(const Key('save_weekly_schedule_btn')));
      await tester.pumpAndSettle();

      // Verified updated schedule state
      expect(SpendingNotificationService.instance.weeklyDay, equals(DateTime.friday));
      expect(find.textContaining('Every Friday at 09:00 AM'), findsOneWidget);
    });

    testWidgets('Tapping monthly schedule row opens monthly bottom sheet with 1..31 chips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await SpendingNotificationService.instance.setNotificationsEnabled(true);

      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Tap monthly schedule row
      await tester.tap(find.byKey(const Key('monthly_schedule_row')));
      await tester.pumpAndSettle();

      // Bottom sheet should be open
      expect(find.text('Monthly Spending Schedule'), findsOneWidget);
      expect(find.text('DAY OF MONTH'), findsOneWidget);
      expect(find.byKey(const Key('monthly_day_chip_1')), findsOneWidget);
      expect(find.byKey(const Key('monthly_day_chip_15')), findsOneWidget);
      expect(find.byKey(const Key('monthly_day_chip_31')), findsOneWidget);
      expect(find.byKey(const Key('monthly_time_picker_btn')), findsOneWidget);
      expect(find.byKey(const Key('save_monthly_schedule_btn')), findsOneWidget);

      // Select 15th (scroll into view if needed in horizontal row)
      await tester.ensureVisible(find.byKey(const Key('monthly_day_chip_15')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('monthly_day_chip_15')));
      await tester.pumpAndSettle();

      // Save schedule
      await tester.tap(find.byKey(const Key('save_monthly_schedule_btn')));
      await tester.pumpAndSettle();

      // Verified updated schedule state
      expect(SpendingNotificationService.instance.monthlyDay, equals(15));
      expect(find.textContaining('On the 15th of the month at 09:00 AM'), findsOneWidget);
    });

    testWidgets('Tapping test notification buttons triggers notifications',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await SpendingNotificationService.instance.setNotificationsEnabled(true);
      SpendingNotificationService.instance.sentNotificationIds.clear();

      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Tap Send Test Weekly Notification
      await tester.tap(find.byKey(const Key('test_weekly_notification_btn')));
      await tester.pump();

      expect(SpendingNotificationService.instance.sentNotificationIds,
          contains(SpendingNotificationService.testWeeklyNotificationId));

      // Tap Send Test Monthly Notification
      await tester.tap(find.byKey(const Key('test_monthly_notification_btn')));
      await tester.pump();

      expect(SpendingNotificationService.instance.sentNotificationIds,
          contains(SpendingNotificationService.testMonthlyNotificationId));
    });

    testWidgets('Toggling weekly or monthly OFF hides their schedule row and test button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await SpendingNotificationService.instance.setNotificationsEnabled(true);

      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Turn OFF weekly
      await tester.tap(find.byKey(const Key('weekly_notification_switch')));
      await tester.pumpAndSettle();

      expect(SpendingNotificationService.instance.weeklySpendingEnabled, isFalse);
      expect(find.byKey(const Key('weekly_schedule_row')), findsNothing);
      expect(find.byKey(const Key('test_weekly_notification_btn')), findsNothing);

      // Turn OFF monthly
      await tester.tap(find.byKey(const Key('monthly_notification_switch')));
      await tester.pumpAndSettle();

      expect(SpendingNotificationService.instance.monthlySpendingEnabled, isFalse);
      expect(find.byKey(const Key('monthly_schedule_row')), findsNothing);
      expect(find.byKey(const Key('test_monthly_notification_btn')), findsNothing);
    });
  });
}
