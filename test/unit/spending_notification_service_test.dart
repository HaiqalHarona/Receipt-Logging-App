// File: test/unit/spending_notification_service_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/services/spending_notification_service.dart';

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
  });

  group('SpendingNotificationService Defaults & Initialization Tests', () {
    test('Default settings are properly initialized', () {
      final service = SpendingNotificationService.instance;
      expect(service.notificationsEnabled, isFalse);
      expect(service.weeklySpendingEnabled, isTrue);
      expect(service.weeklyDay, equals(DateTime.monday));
      expect(service.weeklyTime.hour, equals(9));
      expect(service.weeklyTime.minute, equals(0));
      expect(service.monthlySpendingEnabled, isTrue);
      expect(service.monthlyDay, equals(1));
      expect(service.monthlyTime.hour, equals(9));
      expect(service.monthlyTime.minute, equals(0));
    });

    test('init loads persisted settings from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'spending_notifications_enabled': true,
        'spending_weekly_enabled': true,
        'spending_weekly_day': DateTime.friday,
        'spending_weekly_hour': 18,
        'spending_weekly_minute': 30,
        'spending_monthly_enabled': true,
        'spending_monthly_day': 15,
        'spending_monthly_hour': 10,
        'spending_monthly_minute': 15,
      });

      final service = SpendingNotificationService.instance;
      await service.init();

      expect(service.notificationsEnabled, isTrue);
      expect(service.weeklyDay, equals(DateTime.friday));
      expect(service.weeklyTime.hour, equals(18));
      expect(service.weeklyTime.minute, equals(30));
      expect(service.monthlyDay, equals(15));
      expect(service.monthlyTime.hour, equals(10));
      expect(service.monthlyTime.minute, equals(15));
    });
  });

  group('Formatting Helpers Tests', () {
    test('dayOfWeekName returns correct English day for 1..7', () {
      expect(SpendingNotificationService.dayOfWeekName(DateTime.monday), equals('Monday'));
      expect(SpendingNotificationService.dayOfWeekName(DateTime.tuesday), equals('Tuesday'));
      expect(SpendingNotificationService.dayOfWeekName(DateTime.wednesday), equals('Wednesday'));
      expect(SpendingNotificationService.dayOfWeekName(DateTime.thursday), equals('Thursday'));
      expect(SpendingNotificationService.dayOfWeekName(DateTime.friday), equals('Friday'));
      expect(SpendingNotificationService.dayOfWeekName(DateTime.saturday), equals('Saturday'));
      expect(SpendingNotificationService.dayOfWeekName(DateTime.sunday), equals('Sunday'));
    });

    test('dayOfMonthName returns correct ordinal strings for 1..31', () {
      expect(SpendingNotificationService.dayOfMonthName(1), equals('1st of the month'));
      expect(SpendingNotificationService.dayOfMonthName(2), equals('2nd of the month'));
      expect(SpendingNotificationService.dayOfMonthName(3), equals('3rd of the month'));
      expect(SpendingNotificationService.dayOfMonthName(4), equals('4th of the month'));
      expect(SpendingNotificationService.dayOfMonthName(11), equals('11th of the month'));
      expect(SpendingNotificationService.dayOfMonthName(12), equals('12th of the month'));
      expect(SpendingNotificationService.dayOfMonthName(13), equals('13th of the month'));
      expect(SpendingNotificationService.dayOfMonthName(21), equals('21st of the month'));
      expect(SpendingNotificationService.dayOfMonthName(22), equals('22nd of the month'));
      expect(SpendingNotificationService.dayOfMonthName(23), equals('23rd of the month'));
      expect(SpendingNotificationService.dayOfMonthName(31), equals('31st of the month'));
    });

    test('formatTimeOfDay renders 12h AM/PM strings', () {
      expect(SpendingNotificationService.formatTimeOfDay(const TimeOfDay(hour: 9, minute: 0)), equals('09:00 AM'));
      expect(SpendingNotificationService.formatTimeOfDay(const TimeOfDay(hour: 0, minute: 5)), equals('12:05 AM'));
      expect(SpendingNotificationService.formatTimeOfDay(const TimeOfDay(hour: 12, minute: 0)), equals('12:00 PM'));
      expect(SpendingNotificationService.formatTimeOfDay(const TimeOfDay(hour: 14, minute: 30)), equals('02:30 PM'));
      expect(SpendingNotificationService.formatTimeOfDay(const TimeOfDay(hour: 23, minute: 59)), equals('11:59 PM'));
    });
  });

  group('Schedule Next Instance Calculations', () {
    test('nextWeeklyInstance returns the expected future TZDateTime with correct weekday', () {
      final service = SpendingNotificationService.instance;
      final loc = tz.local;
      // Wednesday 2026-09-16 10:00 AM
      final baseDate = tz.TZDateTime(loc, 2026, 9, 16, 10, 0);

      // Next Friday at 09:00 AM
      final nextFriday = service.nextWeeklyInstance(baseDate, DateTime.friday, 9, 0);
      expect(nextFriday.weekday, equals(DateTime.friday));
      expect(nextFriday.isAfter(baseDate), isTrue);
      expect(nextFriday.day, equals(18));
      expect(nextFriday.hour, equals(9));
      expect(nextFriday.minute, equals(0));

      // Same day (Wednesday) but time already passed (08:00 AM) -> should schedule next Wednesday
      final nextWednesday = service.nextWeeklyInstance(baseDate, DateTime.wednesday, 8, 0);
      expect(nextWednesday.weekday, equals(DateTime.wednesday));
      expect(nextWednesday.isAfter(baseDate), isTrue);
      expect(nextWednesday.day, equals(23)); // 7 days later
    });

    test('nextMonthlyInstance returns the expected day and clamps correctly', () {
      final service = SpendingNotificationService.instance;
      final loc = tz.local;
      // 2026-09-12 10:00 AM
      final baseDate = tz.TZDateTime(loc, 2026, 9, 12, 10, 0);

      // Day 15 of current month
      final next15th = service.nextMonthlyInstance(baseDate, 15, 9, 0);
      expect(next15th.month, equals(9));
      expect(next15th.day, equals(15));
      expect(next15th.hour, equals(9));

      // Day 1 of next month (since day 1 already passed for September)
      final next1st = service.nextMonthlyInstance(baseDate, 1, 9, 0);
      expect(next1st.month, equals(10));
      expect(next1st.day, equals(1));
      expect(next1st.hour, equals(9));

      // Day 31 clamped in November (30 days)
      final novDate = tz.TZDateTime(loc, 2026, 11, 2, 10, 0);
      final clampedNov = service.nextMonthlyInstance(novDate, 31, 9, 0);
      expect(clampedNov.month, equals(11));
      expect(clampedNov.day, equals(30)); // Clamped to 30!

      // Day 31 clamped in February 2027 (non-leap year -> 28 days)
      final febDate = tz.TZDateTime(loc, 2027, 2, 1, 10, 0);
      final clampedFeb = service.nextMonthlyInstance(febDate, 31, 9, 0);
      expect(clampedFeb.month, equals(2));
      expect(clampedFeb.day, equals(28)); // Clamped to 28!
    });
  });

  group('Spending Overview & Top 3 Categories + Others Tests', () {
    test('SpendingOverview caps categories at top 3 and aggregates remainder into Others', () {
      final service = SpendingNotificationService.instance;

      // Clean sample receipts across 5 categories
      final now = DateTime(2026, 9, 12, 12, 0);
      final sampleReceipts = [
        Receipt(
          id: 'r1',
          merchant: 'Supermarket',
          date: '2026-09-10',
          amount: 100.0,
          currency: 'USD',
          category: 'Groceries',
        ),
        Receipt(
          id: 'r2',
          merchant: 'Bistro',
          date: '2026-09-10',
          amount: 80.0,
          currency: 'USD',
          category: 'Dining',
        ),
        Receipt(
          id: 'r3',
          merchant: 'Gas Station',
          date: '2026-09-09',
          amount: 50.0,
          currency: 'USD',
          category: 'Transport',
        ),
        Receipt(
          id: 'r4',
          merchant: 'Cinema',
          date: '2026-09-08',
          amount: 30.0,
          currency: 'USD',
          category: 'Entertainment',
        ),
        Receipt(
          id: 'r5',
          merchant: 'Bookstore',
          date: '2026-09-07',
          amount: 20.0,
          currency: 'USD',
          category: 'Books',
        ),
      ];

      // Save into repository
      for (final r in sampleReceipts) {
        ReceiptRepository.instance.saveReceipt(r);
      }

      final weeklyOverview = service.getWeeklySpendingOverview(now);
      expect(weeklyOverview.totalAmount, equals(280.0));
      expect(weeklyOverview.transactionCount, equals(5));

      // Should have exactly 4 categories: Top 3 (Groceries 100, Dining 80, Transport 50) + Others (30+20=50)
      expect(weeklyOverview.categories.length, equals(4));
      expect(weeklyOverview.categories[0].category, equals('Groceries'));
      expect(weeklyOverview.categories[0].amount, equals(100.0));
      expect(weeklyOverview.categories[1].category, equals('Dining'));
      expect(weeklyOverview.categories[1].amount, equals(80.0));
      expect(weeklyOverview.categories[2].category, equals('Transport'));
      expect(weeklyOverview.categories[2].amount, equals(50.0));
      expect(weeklyOverview.categories[3].category, equals('Others'));
      expect(weeklyOverview.categories[3].amount, equals(50.0));
    });

    test('SpendingOverview does NOT add Others if total categories <= 3', () {
      final service = SpendingNotificationService.instance;
      final now = DateTime(2026, 9, 12, 12, 0);

      // Remove existing and add only 2 categories
      ReceiptRepository.instance.deleteReceipt('r1');
      ReceiptRepository.instance.deleteReceipt('r2');
      ReceiptRepository.instance.deleteReceipt('r3');
      ReceiptRepository.instance.deleteReceipt('r4');
      ReceiptRepository.instance.deleteReceipt('r5');

      ReceiptRepository.instance.saveReceipt(const Receipt(
        id: 'r_groc',
        merchant: 'Grocer',
        date: '2026-09-10',
        amount: 40.0,
        currency: 'USD',
        category: 'Groceries',
      ));
      ReceiptRepository.instance.saveReceipt(const Receipt(
        id: 'r_dine',
        merchant: 'Diner',
        date: '2026-09-10',
        amount: 30.0,
        currency: 'USD',
        category: 'Dining',
      ));

      final weeklyOverview = service.getWeeklySpendingOverview(now);
      expect(weeklyOverview.categories.length, equals(2));
      expect(weeklyOverview.categories.any((c) => c.category == 'Others'), isFalse);
    });

    test('Guest mode suppresses category breakdown in notification body', () {
      final service = SpendingNotificationService.instance;
      final now = DateTime(2026, 9, 12, 12, 0);

      ReceiptRepository.instance.saveReceipt(const Receipt(
        id: 'r_guest_1',
        merchant: 'Market',
        date: '2026-09-10',
        amount: 50.0,
        currency: 'USD',
        category: 'Groceries',
      ));
      ReceiptRepository.instance.saveReceipt(const Receipt(
        id: 'r_guest_2',
        merchant: 'Cafe',
        date: '2026-09-10',
        amount: 25.0,
        currency: 'USD',
        category: 'Dining',
      ));

      final overview = service.getWeeklySpendingOverview(now);
      expect(overview.transactionCount, equals(2));

      // In guest mode (not logged in):
      final guestBody = overview.notificationBodyForLoginState(false);
      expect(guestBody, contains('Sign in to view category breakdown'));
      expect(guestBody, isNot(contains('Groceries:')));

      // In authenticated mode:
      final authBody = overview.notificationBodyForLoginState(true);
      expect(authBody, contains('Groceries:'));
      expect(authBody, contains('Dining:'));
    });

    test('Zero spending shows friendly empty message', () {
      final service = SpendingNotificationService.instance;
      // Reference date far in the future where no receipts exist
      final futureDate = DateTime(2035, 1, 1);
      final overview = service.getWeeklySpendingOverview(futureDate);

      expect(overview.totalAmount, equals(0.0));
      expect(overview.transactionCount, equals(0));
      expect(overview.notificationBodyForLoginState(true), equals('No spending recorded this week.'));
      expect(overview.notificationBodyForLoginState(false), equals('No spending recorded this week.'));
    });
  });

  group('Mutators and Persistence Tests', () {
    test('setNotificationsEnabled toggles state and persists', () async {
      final service = SpendingNotificationService.instance;
      await service.setNotificationsEnabled(false);

      await service.setNotificationsEnabled(true);
      expect(service.notificationsEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('spending_notifications_enabled'), isTrue);

      await service.setNotificationsEnabled(false);
      expect(service.notificationsEnabled, isFalse);
      expect(prefs.getBool('spending_notifications_enabled'), isFalse);
    });

    test('setWeeklyDay and setWeeklyTime persist correctly', () async {
      final service = SpendingNotificationService.instance;
      await service.setWeeklyDay(DateTime.thursday);
      await service.setWeeklyTime(const TimeOfDay(hour: 17, minute: 45));

      expect(service.weeklyDay, equals(DateTime.thursday));
      expect(service.weeklyTime.hour, equals(17));
      expect(service.weeklyTime.minute, equals(45));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('spending_weekly_day'), equals(DateTime.thursday));
      expect(prefs.getInt('spending_weekly_hour'), equals(17));
      expect(prefs.getInt('spending_weekly_minute'), equals(45));
    });

    test('setMonthlyDay and setMonthlyTime persist correctly', () async {
      final service = SpendingNotificationService.instance;
      await service.setMonthlyDay(28);
      await service.setMonthlyTime(const TimeOfDay(hour: 8, minute: 15));

      expect(service.monthlyDay, equals(28));
      expect(service.monthlyTime.hour, equals(8));
      expect(service.monthlyTime.minute, equals(15));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('spending_monthly_day'), equals(28));
      expect(prefs.getInt('spending_monthly_hour'), equals(8));
      expect(prefs.getInt('spending_monthly_minute'), equals(15));
    });

    test('Instant test notifications append IDs to sentNotificationIds list', () async {
      final service = SpendingNotificationService.instance;
      service.sentNotificationIds.clear();

      await service.triggerTestWeeklyNotification();
      expect(service.sentNotificationIds, contains(SpendingNotificationService.testWeeklyNotificationId));

      await service.triggerTestMonthlyNotification();
      expect(service.sentNotificationIds, contains(SpendingNotificationService.testMonthlyNotificationId));
    });

    test('parseDateString parses human-readable dates, ISO, Today, and handles fallbacks', () {
      // 1. MMM DD, YYYY
      final aug = SpendingNotificationService.parseDateString('Aug 01, 2026');
      expect(aug, isNotNull);
      expect(aug!.year, equals(2026));
      expect(aug.month, equals(8));
      expect(aug.day, equals(1));

      // 2. Full Month name
      final sep = SpendingNotificationService.parseDateString('September 12, 2026');
      expect(sep, isNotNull);
      expect(sep!.year, equals(2026));
      expect(sep.month, equals(9));
      expect(sep.day, equals(12));

      // 3. ISO-8601
      final iso = SpendingNotificationService.parseDateString('2026-09-05');
      expect(iso, isNotNull);
      expect(iso!.year, equals(2026));
      expect(iso.month, equals(9));
      expect(iso.day, equals(5));

      // 4. Relative Today/Yesterday
      final today = SpendingNotificationService.parseDateString('Today');
      expect(today, isNotNull);
      expect(today!.day, equals(DateTime.now().day));

      final yesterday = SpendingNotificationService.parseDateString('Yesterday');
      expect(yesterday, isNotNull);

      // 5. Fallback to createdAt
      final fallbackDate = DateTime(2026, 7, 15);
      final fallbackResult = SpendingNotificationService.parseDateString('Invalid Date String', fallbackDate);
      expect(fallbackResult, equals(fallbackDate));

      final emptyResult = SpendingNotificationService.parseDateString('', fallbackDate);
      expect(emptyResult, equals(fallbackDate));
    });

    test('SpendingOverview processes real-world human-readable receipt dates', () {
      final service = SpendingNotificationService.instance;
      final refDate = DateTime(2026, 9, 12, 14, 0);

      // Add receipts with app standard 'MMM dd, yyyy' dates spanning the last 4 weeks
      ReceiptRepository.instance.saveReceipt(const Receipt(
        id: 'real_r1',
        merchant: 'Supermarket',
        date: 'Sep 10, 2026', // Within last 7 days & last 30 days
        amount: 85.0,
        currency: 'USD',
        category: 'Groceries',
      ));
      ReceiptRepository.instance.saveReceipt(const Receipt(
        id: 'real_r2',
        merchant: 'Bistro',
        date: 'Aug 25, 2026', // Within last 30 days (18 days ago), outside last 7 days
        amount: 45.0,
        currency: 'USD',
        category: 'Dining',
      ));
      ReceiptRepository.instance.saveReceipt(const Receipt(
        id: 'real_r3',
        merchant: 'Gas Station',
        date: 'Aug 18, 2026', // Within last 30 days (25 days ago), outside last 7 days
        amount: 30.0,
        currency: 'USD',
        category: 'Transport',
      ));

      // Weekly overview should include only real_r1 (Sep 10)
      final weekly = service.getWeeklySpendingOverview(refDate);
      expect(weekly.transactionCount, equals(1));
      expect(weekly.totalAmount, equals(85.0));
      expect(weekly.categories.first.category, equals('Groceries'));

      // Monthly overview should include all 3 receipts (past 30 days covers the last 4 weeks)
      final monthly = service.getMonthlySpendingOverview(refDate);
      expect(monthly.transactionCount, equals(3));
      expect(monthly.totalAmount, equals(160.0));
      expect(monthly.categories.length, equals(3));
      expect(monthly.notificationBodyForLoginState(true), contains('Groceries:'));
      expect(monthly.notificationBodyForLoginState(true), contains('Dining:'));
      expect(monthly.notificationBodyForLoginState(true), contains('Transport:'));
    });

    test('Timezone configuration sets local location and schedules with local offset', () {
      final service = SpendingNotificationService.instance;
      // Configure local timezone to Asia/Kuala_Lumpur (UTC+8)
      service.configureTimezoneForTest('Asia/Kuala_Lumpur');
      expect(tz.local.name, equals('Asia/Kuala_Lumpur'));

      // 2026-09-12 14:31:20 in Asia/Kuala_Lumpur (+08:00)
      final fromDate = tz.TZDateTime(tz.local, 2026, 9, 12, 14, 31, 20);
      expect(fromDate.timeZoneOffset, equals(const Duration(hours: 8)));

      // Schedule for Saturday at 14:33
      final nextWeekly = service.nextWeeklyInstance(
        fromDate,
        DateTime.saturday,
        14,
        33,
      );

      // Verify it schedules for 14:33 on the same day in UTC+8
      expect(nextWeekly.year, equals(2026));
      expect(nextWeekly.month, equals(9));
      expect(nextWeekly.day, equals(12));
      expect(nextWeekly.hour, equals(14));
      expect(nextWeekly.minute, equals(33));
      expect(nextWeekly.timeZoneOffset, equals(const Duration(hours: 8)));
      expect(nextWeekly.isAfter(fromDate), isTrue);

      // Schedule for 12th of month at 14:33
      final nextMonthly = service.nextMonthlyInstance(
        fromDate,
        12,
        14,
        33,
      );
      expect(nextMonthly.year, equals(2026));
      expect(nextMonthly.month, equals(9));
      expect(nextMonthly.day, equals(12));
      expect(nextMonthly.hour, equals(14));
      expect(nextMonthly.minute, equals(33));
      expect(nextMonthly.timeZoneOffset, equals(const Duration(hours: 8)));
      expect(nextMonthly.isAfter(fromDate), isTrue);

      // Reset timezone back to UTC
      service.configureTimezoneForTest('UTC');
    });
  });
}
