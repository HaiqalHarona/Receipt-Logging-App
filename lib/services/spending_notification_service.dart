// File: lib/services/spending_notification_service.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../cloud/services/auth_service.dart';
import '../data/repositories/receipt_repository.dart';
import '../services/app_logger_service.dart';
import '../services/currency_service.dart';
import '../ui/core/utils/category_utils.dart';

/// Overview of spending for an individual category within a time window.
class SpendingCategoryOverview {
  final String category;
  final double amount;
  final double percentage;
  final String formattedAmount;

  const SpendingCategoryOverview({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.formattedAmount,
  });
}

/// Comprehensive spending overview for a weekly or monthly period.
class SpendingOverview {
  final String periodName; // 'Weekly' or 'Monthly'
  final DateTime startDate;
  final DateTime endDate;
  final double totalAmount;
  final String formattedTotal;
  final int transactionCount;
  final List<SpendingCategoryOverview> categories;

  const SpendingOverview({
    required this.periodName,
    required this.startDate,
    required this.endDate,
    required this.totalAmount,
    required this.formattedTotal,
    required this.transactionCount,
    required this.categories,
  });

  /// Notification header line.
  String get notificationTitle => '$periodName Spending: $formattedTotal';

  String get _periodLabel =>
      periodName.toLowerCase() == 'weekly' ? 'week' : 'month';

  /// Standard single-line body taking authentication into account.
  /// Guests see total and receipt count; authenticated users see category breakdown.
  String notificationBodyForLoginState(bool isLoggedIn) {
    if (transactionCount == 0 || categories.isEmpty) {
      return 'No spending recorded this $_periodLabel.';
    }
    if (!isLoggedIn) {
      return 'Total: $formattedTotal ($transactionCount receipts). '
          'Sign in to view category breakdown.';
    }
    return categories
        .map((c) => '${c.category}: ${c.formattedAmount}')
        .join(' • ');
  }

  /// Default notification body resolving login state via AuthService.
  String get notificationBody =>
      notificationBodyForLoginState(AuthService.instance.isLoggedIn);

  /// Expanded multi-line summary taking authentication into account.
  String expandedSummaryForLoginState(bool isLoggedIn) {
    if (transactionCount == 0 || categories.isEmpty) {
      return 'No spending recorded this $_periodLabel.';
    }
    if (!isLoggedIn) {
      return 'Total: $formattedTotal ($transactionCount receipts)\n'
          'Sign in to view full category breakdown.';
    }
    final buffer = StringBuffer();
    buffer.writeln('Total: $formattedTotal ($transactionCount receipts)');
    for (final c in categories) {
      buffer.writeln(
          '• ${c.category}: ${c.formattedAmount} (${c.percentage.toStringAsFixed(1)}%)');
    }
    return buffer.toString().trim();
  }

  /// Default expanded summary resolving login state via AuthService.
  String get expandedSummary =>
      expandedSummaryForLoginState(AuthService.instance.isLoggedIn);
}

/// Centralized service managing scheduled local notifications for weekly and monthly spending.
///
/// Features:
/// - Configurable weekly schedule: Day of week (Mon-Sun) and delivery time.
/// - Configurable monthly schedule: Day of month (1-31) and delivery time.
/// - Master enable/disable toggle and granular weekly/monthly toggles.
/// - Local device notifications powered by [FlutterLocalNotificationsPlugin].
/// - Dynamic top-3 category breakdown (+ Others) computed from [ReceiptRepository].
/// - Guest mode support (hides category breakdown until logged in).
/// - Local persistence via [SharedPreferences].
/// - Safe fallback in test environments and desktop/web.
class SpendingNotificationService extends ChangeNotifier {
  static final SpendingNotificationService instance =
      SpendingNotificationService._internal();

  FlutterLocalNotificationsPlugin _notificationsPlugin;
  final ReceiptRepository _repository;
  final CurrencyService _currencyService;

  SpendingNotificationService._internal({
    FlutterLocalNotificationsPlugin? plugin,
    ReceiptRepository? repository,
    CurrencyService? currencyService,
  })  : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _repository = repository ?? ReceiptRepository.instance,
        _currencyService = currencyService ?? CurrencyService.instance;

  @visibleForTesting
  factory SpendingNotificationService.forTest({
    FlutterLocalNotificationsPlugin? plugin,
    ReceiptRepository? repository,
    CurrencyService? currencyService,
  }) {
    return SpendingNotificationService._internal(
      plugin: plugin,
      repository: repository,
      currencyService: currencyService,
    );
  }

  // ── Notification IDs ────────────────────────────────────────────────────────
  static const int weeklyNotificationId = 1001;
  static const int monthlyNotificationId = 1002;
  static const int testWeeklyNotificationId = 2001;
  static const int testMonthlyNotificationId = 2002;

  // ── Channel Information ───────────────────────────────────────────────────
  static const String channelId = 'spending_reminders';
  static const String channelName = 'Spending Reminders';
  static const String channelDescription =
      'Scheduled notifications with weekly and monthly spending and category overviews.';

  // ── SharedPreferences Keys ────────────────────────────────────────────────
  static const String _kNotificationsEnabled = 'spending_notifications_enabled';
  static const String _kWeeklyEnabled = 'spending_weekly_enabled';
  static const String _kWeeklyDay = 'spending_weekly_day';
  static const String _kWeeklyHour = 'spending_weekly_hour';
  static const String _kWeeklyMinute = 'spending_weekly_minute';
  static const String _kMonthlyEnabled = 'spending_monthly_enabled';
  static const String _kMonthlyDay = 'spending_monthly_day';
  static const String _kMonthlyHour = 'spending_monthly_hour';
  static const String _kMonthlyMinute = 'spending_monthly_minute';

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isInitialized = false;
  bool _notificationsEnabled = false;
  bool _weeklySpendingEnabled = true;
  int _weeklyDay = DateTime.monday; // 1 = Monday, 7 = Sunday
  TimeOfDay _weeklyTime = const TimeOfDay(hour: 9, minute: 0);

  bool _monthlySpendingEnabled = true;
  int _monthlyDay = 1; // 1st of every month (supports 1..31)
  TimeOfDay _monthlyTime = const TimeOfDay(hour: 9, minute: 0);

  bool _isPermissionGranted = false;

  // Tracking for diagnostics and test assertions
  int? lastScheduledWeeklyId;
  DateTime? lastScheduledWeeklyDate;
  int? lastScheduledMonthlyId;
  DateTime? lastScheduledMonthlyDate;
  final List<int> sentNotificationIds = [];

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get weeklySpendingEnabled => _weeklySpendingEnabled;
  int get weeklyDay => _weeklyDay;
  TimeOfDay get weeklyTime => _weeklyTime;
  bool get monthlySpendingEnabled => _monthlySpendingEnabled;
  int get monthlyDay => _monthlyDay;
  TimeOfDay get monthlyTime => _monthlyTime;
  bool get isPermissionGranted => _isPermissionGranted;

  bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Human-readable day name for the weekly schedule.
  String get weeklyDayName => dayOfWeekName(_weeklyDay);

  /// Human-readable day description for the monthly schedule.
  String get monthlyDayName => dayOfMonthName(_monthlyDay);

  /// Formats a [TimeOfDay] into 12-hour AM/PM string.
  static String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Human-readable name for day of week.
  static String dayOfWeekName(int day) {
    switch (day) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  /// Human-readable ordinal representation for day of month (1..31).
  static String dayOfMonthName(int day) {
    if (day >= 11 && day <= 13) {
      return '${day}th of the month';
    }
    switch (day % 10) {
      case 1:
        return '${day}st of the month';
      case 2:
        return '${day}nd of the month';
      case 3:
        return '${day}rd of the month';
      default:
        return '${day}th of the month';
    }
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Initializes timezone data, persistent settings, and notification channels.
  Future<void> init({FlutterLocalNotificationsPlugin? plugin}) async {
    if (plugin != null) {
      _notificationsPlugin = plugin;
    }

    AppLogger.info('Notification', '[SpendingNotificationService] Initializing...');

    // 1. Initialize local timezone
    await _configureLocalTimezone();

    // 2. Load persisted settings
    await _loadPersistedSettings();

    // 3. Initialize plugin on supported platforms
    if (!_isTestEnvironment && !kIsWeb) {
      try {
        const androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const darwinSettings = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        const linuxSettings =
            LinuxInitializationSettings(defaultActionName: 'Open');

        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
          linux: linuxSettings,
        );

        await _notificationsPlugin.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (details) {
            AppLogger.info(
              'Notification',
              'Notification tapped with payload: ${details.payload}',
            );
          },
        );

        // Pre-create high-importance notification channel on Android
        if (Platform.isAndroid) {
          final androidImpl = _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          await androidImpl?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              description: channelDescription,
              importance: Importance.high,
            ),
          );
        }
      } catch (e, st) {
        AppLogger.warning('Notification', 'Notification plugin init warning: $e', st);
      }
    }

    // 4. Hook reactive updates: whenever receipts or currency changes,
    // refresh scheduled notification contents
    _repository.removeListener(_onDataChanged);
    _repository.addListener(_onDataChanged);
    _currencyService.removeListener(_onDataChanged);
    _currencyService.addListener(_onDataChanged);

    _isInitialized = true;

    // 5. Schedule notifications if currently enabled
    if (_notificationsEnabled) {
      await scheduleNotifications();
    }

    AppLogger.info('Notification',
        '[SpendingNotificationService] Initialized (enabled: $_notificationsEnabled)');
    notifyListeners();
  }

  void _onDataChanged() {
    if (_notificationsEnabled) {
      scheduleNotifications();
    }
    notifyListeners();
  }

  Future<void> _loadPersistedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled =
          prefs.getBool(_kNotificationsEnabled) ?? _notificationsEnabled;
      _weeklySpendingEnabled =
          prefs.getBool(_kWeeklyEnabled) ?? _weeklySpendingEnabled;
      _weeklyDay = prefs.getInt(_kWeeklyDay) ?? _weeklyDay;
      final wHour = prefs.getInt(_kWeeklyHour) ?? _weeklyTime.hour;
      final wMin = prefs.getInt(_kWeeklyMinute) ?? _weeklyTime.minute;
      _weeklyTime = TimeOfDay(hour: wHour, minute: wMin);

      _monthlySpendingEnabled =
          prefs.getBool(_kMonthlyEnabled) ?? _monthlySpendingEnabled;
      _monthlyDay = prefs.getInt(_kMonthlyDay) ?? _monthlyDay;
      final mHour = prefs.getInt(_kMonthlyHour) ?? _monthlyTime.hour;
      final mMin = prefs.getInt(_kMonthlyMinute) ?? _monthlyTime.minute;
      _monthlyTime = TimeOfDay(hour: mHour, minute: mMin);
    } catch (e) {
      AppLogger.warning('Notification', 'Failed to load notification settings: $e');
    }
  }

  // ── Permission Requests ───────────────────────────────────────────────────

  /// Requests device notification permissions on Android 13+ and iOS/macOS.
  Future<bool> requestPermissions() async {
    if (_isTestEnvironment || kIsWeb) {
      _isPermissionGranted = true;
      notifyListeners();
      return true;
    }

    try {
      bool? granted = false;
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        granted = await androidImpl?.requestNotificationsPermission();
        try {
          final canExact =
              await androidImpl?.canScheduleExactNotifications() ?? true;
          if (!canExact) {
            await androidImpl?.requestExactAlarmsPermission();
          }
        } catch (_) {}
      } else if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (Platform.isMacOS) {
        final macImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>();
        granted = await macImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        granted = true;
      }

      _isPermissionGranted = granted ?? false;
      notifyListeners();
      return _isPermissionGranted;
    } catch (e) {
      AppLogger.warning('Notification', 'Error requesting permissions: $e');
      return false;
    }
  }

  // ── Settings Mutators ─────────────────────────────────────────────────────

  /// Turns spending notifications on or off globally.
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;

    if (enabled) {
      await requestPermissions();
      await scheduleNotifications();
    } else {
      await cancelNotifications();
    }

    await _persist();
    notifyListeners();
  }

  /// Toggles the weekly spending summary notification.
  Future<void> setWeeklySpendingEnabled(bool enabled) async {
    if (_weeklySpendingEnabled == enabled) return;
    _weeklySpendingEnabled = enabled;

    if (_notificationsEnabled) {
      if (enabled) {
        await _scheduleWeeklyNotification();
      } else {
        await cancelWeeklyNotification();
      }
    }

    await _persist();
    notifyListeners();
  }

  /// Updates the day of week for weekly notifications (1 = Monday .. 7 = Sunday).
  Future<void> setWeeklyDay(int day) async {
    if (day < 1 || day > 7) return;
    _weeklyDay = day;

    if (_notificationsEnabled && _weeklySpendingEnabled) {
      await _scheduleWeeklyNotification();
    }

    await _persist();
    notifyListeners();
  }

  /// Updates the delivery time for weekly notifications.
  Future<void> setWeeklyTime(TimeOfDay time) async {
    _weeklyTime = time;

    if (_notificationsEnabled && _weeklySpendingEnabled) {
      await _scheduleWeeklyNotification();
    }

    await _persist();
    notifyListeners();
  }

  /// Toggles the monthly spending summary notification.
  Future<void> setMonthlySpendingEnabled(bool enabled) async {
    if (_monthlySpendingEnabled == enabled) return;
    _monthlySpendingEnabled = enabled;

    if (_notificationsEnabled) {
      if (enabled) {
        await _scheduleMonthlyNotification();
      } else {
        await cancelMonthlyNotification();
      }
    }

    await _persist();
    notifyListeners();
  }

  /// Updates the day of the month for monthly notifications (1..31).
  Future<void> setMonthlyDay(int day) async {
    if (day < 1 || day > 31) return;
    _monthlyDay = day;

    if (_notificationsEnabled && _monthlySpendingEnabled) {
      await _scheduleMonthlyNotification();
    }

    await _persist();
    notifyListeners();
  }

  /// Updates the delivery time for monthly notifications.
  Future<void> setMonthlyTime(TimeOfDay time) async {
    _monthlyTime = time;

    if (_notificationsEnabled && _monthlySpendingEnabled) {
      await _scheduleMonthlyNotification();
    }

    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotificationsEnabled, _notificationsEnabled);
      await prefs.setBool(_kWeeklyEnabled, _weeklySpendingEnabled);
      await prefs.setInt(_kWeeklyDay, _weeklyDay);
      await prefs.setInt(_kWeeklyHour, _weeklyTime.hour);
      await prefs.setInt(_kWeeklyMinute, _weeklyTime.minute);
      await prefs.setBool(_kMonthlyEnabled, _monthlySpendingEnabled);
      await prefs.setInt(_kMonthlyDay, _monthlyDay);
      await prefs.setInt(_kMonthlyHour, _monthlyTime.hour);
      await prefs.setInt(_kMonthlyMinute, _monthlyTime.minute);
    } catch (e) {
      AppLogger.warning('Notification', 'Failed to persist notification settings: $e');
    }
  }

  // ── Spending Calculations ─────────────────────────────────────────────────

  /// Computes weekly spending and breakdown by category over the past 7 days.
  SpendingOverview getWeeklySpendingOverview([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final startDay = now.subtract(const Duration(days: 7));
    final start = DateTime(startDay.year, startDay.month, startDay.day, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return _computeOverview(
      periodName: 'Weekly',
      startDate: start,
      endDate: end,
    );
  }

  /// Computes monthly spending and breakdown by category over the past 30 days.
  SpendingOverview getMonthlySpendingOverview([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final startDay = now.subtract(const Duration(days: 30));
    final start = DateTime(startDay.year, startDay.month, startDay.day, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return _computeOverview(
      periodName: 'Monthly',
      startDate: start,
      endDate: end,
    );
  }

  SpendingOverview _computeOverview({
    required String periodName,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final receipts = _repository.receipts;
    double total = 0.0;
    int count = 0;
    final Map<String, double> categoryMap = {};

    for (final receipt in receipts) {
      final parsedDate = parseDateString(receipt.date, receipt.createdAt);
      if (parsedDate == null) continue;

      if (!parsedDate.isBefore(startDate) && !parsedDate.isAfter(endDate)) {
        final converted =
            _currencyService.convert(receipt.amount, receipt.currency);
        total += converted;
        count++;

        final tokens = receipt.category
            .split(',')
            .map((c) => CategoryUtils.sanitize(c).trim())
            .where((c) => c.isNotEmpty)
            .toList();

        String catName = tokens.isNotEmpty ? tokens.first : 'Uncategorised';
        if (catName.isEmpty || catName.toLowerCase() == 'uncategorized') {
          catName = 'Uncategorised';
        }
        catName = _capitalize(catName);

        categoryMap[catName] = (categoryMap[catName] ?? 0.0) + converted;
      }
    }

    final sortedEntries = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Cap at top 3 categories + catch-all "Others"
    const int maxCategories = 3;
    final List<MapEntry<String, double>> topEntries;
    double othersAmount = 0.0;

    if (sortedEntries.length > maxCategories) {
      topEntries = sortedEntries.take(maxCategories).toList();
      othersAmount = sortedEntries
          .skip(maxCategories)
          .fold(0.0, (sum, e) => sum + e.value);
    } else {
      topEntries = sortedEntries;
    }

    final categories = <SpendingCategoryOverview>[
      for (final e in topEntries)
        SpendingCategoryOverview(
          category: e.key,
          amount: e.value,
          percentage: total > 0 ? (e.value / total) * 100.0 : 0.0,
          formattedAmount: _currencyService.format(
            e.value,
            fromCurrencyCode: _currencyService.currentCurrency,
          ),
        ),
      if (othersAmount > 0)
        SpendingCategoryOverview(
          category: 'Others',
          amount: othersAmount,
          percentage: total > 0 ? (othersAmount / total) * 100.0 : 0.0,
          formattedAmount: _currencyService.format(
            othersAmount,
            fromCurrencyCode: _currencyService.currentCurrency,
          ),
        ),
    ];

    final formattedTotal = _currencyService.format(
      total,
      fromCurrencyCode: _currencyService.currentCurrency,
    );

    return SpendingOverview(
      periodName: periodName,
      startDate: startDate,
      endDate: endDate,
      totalAmount: total,
      formattedTotal: formattedTotal,
      transactionCount: count,
      categories: categories,
    );
  }

  /// Robust date parser supporting ISO-8601, `"MMM DD, YYYY"`, `"Today"`,
  /// `"Yesterday"`, and fallback to [fallbackCreatedAt].
  static DateTime? parseDateString(String dateStr, [DateTime? fallbackCreatedAt]) {
    final trimmed = dateStr.trim();
    if (trimmed.isEmpty) return fallbackCreatedAt;

    final lower = trimmed.toLowerCase();
    if (lower == 'today') {
      return DateTime.now();
    }
    if (lower == 'yesterday') {
      return DateTime.now().subtract(const Duration(days: 1));
    }

    try {
      // 1. Try ISO-8601 (e.g. 2026-09-12 or 2026-09-12T14:00:00Z)
      final iso = DateTime.tryParse(trimmed);
      if (iso != null) return iso;

      // 2. Try "MMM DD, YYYY" or "MMMM DD, YYYY" (e.g. "Aug 01, 2026", "Sep 12, 2026")
      const monthMap = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };

      final parts = trimmed.split(RegExp(r'[,\s]+'));
      if (parts.length >= 3) {
        final rawMonth = parts[0].toLowerCase();
        final prefix = rawMonth.length >= 3 ? rawMonth.substring(0, 3) : rawMonth;
        final m = monthMap[prefix];
        final d = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (m != null && d != null && y != null) {
          return DateTime(y, m, d);
        }
      }

      // 3. Try separator-based strings (e.g. YYYY-MM-DD or DD/MM/YYYY)
      final sepParts = trimmed.split(RegExp(r'[-/]'));
      if (sepParts.length == 3) {
        final p0 = int.tryParse(sepParts[0]);
        final p1 = int.tryParse(sepParts[1]);
        final p2 = int.tryParse(sepParts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (p0 > 1000) {
            return DateTime(p0, p1, p2);
          } else if (p2 > 1000) {
            return DateTime(p2, p1, p0);
          }
        }
      }
    } catch (_) {}

    return fallbackCreatedAt;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // ── Scheduling Implementation ─────────────────────────────────────────────

  /// Schedules both weekly and monthly notifications according to active preferences.
  Future<void> scheduleNotifications() async {
    if (!_notificationsEnabled) {
      await cancelNotifications();
      return;
    }

    if (_weeklySpendingEnabled) {
      await _scheduleWeeklyNotification();
    } else {
      await cancelWeeklyNotification();
    }

    if (_monthlySpendingEnabled) {
      await _scheduleMonthlyNotification();
    } else {
      await cancelMonthlyNotification();
    }
  }

  /// Cancels all scheduled spending notifications.
  Future<void> cancelNotifications() async {
    await cancelWeeklyNotification();
    await cancelMonthlyNotification();
  }

  /// Cancels weekly notification.
  Future<void> cancelWeeklyNotification() async {
    lastScheduledWeeklyId = null;
    lastScheduledWeeklyDate = null;
    if (_isTestEnvironment || kIsWeb) {
      AppLogger.info('Notification', 'Weekly spending notification cancelled (test env).');
      return;
    }
    try {
      await _notificationsPlugin.cancel(id: weeklyNotificationId);
      AppLogger.info('Notification', 'Weekly spending notification cancelled.');
    } catch (e) {
      AppLogger.warning('Notification', 'Error cancelling weekly notification: $e');
    }
  }

  /// Cancels monthly notification.
  Future<void> cancelMonthlyNotification() async {
    lastScheduledMonthlyId = null;
    lastScheduledMonthlyDate = null;
    if (_isTestEnvironment || kIsWeb) {
      AppLogger.info('Notification', 'Monthly spending notification cancelled (test env).');
      return;
    }
    try {
      await _notificationsPlugin.cancel(id: monthlyNotificationId);
      AppLogger.info('Notification', 'Monthly spending notification cancelled.');
    } catch (e) {
      AppLogger.warning('Notification', 'Error cancelling monthly notification: $e');
    }
  }

  /// Calculates the next instance for weekly notification.
  tz.TZDateTime nextWeeklyInstance(
    tz.TZDateTime fromDate,
    int targetWeekday,
    int hour,
    int minute,
  ) {
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      fromDate.location,
      fromDate.year,
      fromDate.month,
      fromDate.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != targetWeekday ||
        scheduledDate.isBefore(fromDate)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Calculates the next instance for monthly notification,
  /// clamping days like 29, 30, 31 to the actual month length.
  tz.TZDateTime nextMonthlyInstance(
    tz.TZDateTime fromDate,
    int targetDayOfMonth,
    int hour,
    int minute,
  ) {
    int year = fromDate.year;
    int month = fromDate.month;
    int safeDay = _clampDayToMonth(year, month, targetDayOfMonth);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      fromDate.location,
      year,
      month,
      safeDay,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(fromDate)) {
      month++;
      if (month > 12) {
        year++;
        month = 1;
      }
      safeDay = _clampDayToMonth(year, month, targetDayOfMonth);
      scheduledDate = tz.TZDateTime(
        fromDate.location,
        year,
        month,
        safeDay,
        hour,
        minute,
      );
    }

    return scheduledDate;
  }

  int _clampDayToMonth(int year, int month, int desiredDay) {
    final nextMonthFirst = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    final daysInMonth =
        nextMonthFirst.subtract(const Duration(days: 1)).day;
    return math.min(desiredDay, daysInMonth);
  }

  Future<void> _scheduleWeeklyNotification() async {
    // Always re-configure timezone immediately before scheduling to guarantee
    // tz.local is correct at the moment the alarm is registered with Android.
    // Without this, if init() ran while the MethodChannel wasn't ready yet,
    // tz.local could still be UTC — causing the alarm to fire 8h off.
    await _configureLocalTimezone();

    final overview = getWeeklySpendingOverview();
    final nowTz = tz.TZDateTime.now(tz.local);
    final scheduledDate = nextWeeklyInstance(
      nowTz,
      _weeklyDay,
      _weeklyTime.hour,
      _weeklyTime.minute,
    );

    lastScheduledWeeklyId = weeklyNotificationId;
    lastScheduledWeeklyDate = scheduledDate;

    final isLoggedIn = AuthService.instance.isLoggedIn;
    final title = overview.notificationTitle;
    final body = overview.notificationBodyForLoginState(isLoggedIn);

    if (_isTestEnvironment || kIsWeb) {
      AppLogger.info(
        'Notification',
        '[Test] Scheduled weekly notification for $scheduledDate: $title',
      );
      return;
    }

    try {
      final details = _buildNotificationDetails(overview, isLoggedIn);
      final scheduleMode = await _resolveAndroidScheduleMode();
      AppLogger.info(
        'Notification',
        'Scheduling weekly notification: tz.local=${tz.local.name}, '
        'scheduledDate=$scheduledDate (mode: $scheduleMode, UTC epoch: ${scheduledDate.millisecondsSinceEpoch})',
      );
      try {
        await _notificationsPlugin.zonedSchedule(
          id: weeklyNotificationId,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          title: title,
          body: body,
          payload: 'weekly_spending',
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (scheduleError) {
        if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
          AppLogger.warning(
            'Notification',
            'Failed to schedule weekly notification with $scheduleMode, retrying with inexactAllowWhileIdle: $scheduleError',
          );
          await _notificationsPlugin.zonedSchedule(
            id: weeklyNotificationId,
            scheduledDate: scheduledDate,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: title,
            body: body,
            payload: 'weekly_spending',
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } else {
          rethrow;
        }
      }
      AppLogger.info(
        'Notification',
        'Scheduled weekly spending notification at $scheduledDate',
      );
    } catch (e, st) {
      AppLogger.warning(
        'Notification',
        'Failed to schedule weekly notification: $e',
        st,
      );
    }
  }

  Future<void> _scheduleMonthlyNotification() async {
    // Always re-configure timezone immediately before scheduling (same reason
    // as _scheduleWeeklyNotification — see comment there).
    await _configureLocalTimezone();

    final overview = getMonthlySpendingOverview();
    final nowTz = tz.TZDateTime.now(tz.local);
    final scheduledDate = nextMonthlyInstance(
      nowTz,
      _monthlyDay,
      _monthlyTime.hour,
      _monthlyTime.minute,
    );

    lastScheduledMonthlyId = monthlyNotificationId;
    lastScheduledMonthlyDate = scheduledDate;

    final isLoggedIn = AuthService.instance.isLoggedIn;
    final title = overview.notificationTitle;
    final body = overview.notificationBodyForLoginState(isLoggedIn);

    if (_isTestEnvironment || kIsWeb) {
      AppLogger.info(
        'Notification',
        '[Test] Scheduled monthly notification for $scheduledDate: $title',
      );
      return;
    }

    try {
      final details = _buildNotificationDetails(overview, isLoggedIn);
      final scheduleMode = await _resolveAndroidScheduleMode();
      AppLogger.info(
        'Notification',
        'Scheduling monthly notification: tz.local=${tz.local.name}, '
        'scheduledDate=$scheduledDate (mode: $scheduleMode, UTC epoch: ${scheduledDate.millisecondsSinceEpoch})',
      );
      try {
        await _notificationsPlugin.zonedSchedule(
          id: monthlyNotificationId,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          title: title,
          body: body,
          payload: 'monthly_spending',
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      } catch (scheduleError) {
        if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
          AppLogger.warning(
            'Notification',
            'Failed to schedule monthly notification with $scheduleMode, retrying with inexactAllowWhileIdle: $scheduleError',
          );
          await _notificationsPlugin.zonedSchedule(
            id: monthlyNotificationId,
            scheduledDate: scheduledDate,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: title,
            body: body,
            payload: 'monthly_spending',
            matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          );
        } else {
          rethrow;
        }
      }
      AppLogger.info(
        'Notification',
        'Scheduled monthly spending notification at $scheduledDate',
      );
    } catch (e, st) {
      AppLogger.warning(
        'Notification',
        'Failed to schedule monthly notification: $e',
        st,
      );
    }
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!_isTestEnvironment && !kIsWeb && Platform.isAndroid) {
      try {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final canExact =
            await androidImpl?.canScheduleExactNotifications() ?? true;
        if (!canExact) {
          return AndroidScheduleMode.inexactAllowWhileIdle;
        }
      } catch (_) {}
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }



  /// Resolves device native timezone and configures [tz.local].
  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();

    String? nativeTzName;
    if (!_isTestEnvironment && !kIsWeb) {
      try {
        const channel =
            MethodChannel('com.example.reciept_logging/device_timezone');
        nativeTzName = await channel.invokeMethod<String>('getDeviceTimezone');
      } catch (e) {
        AppLogger.debug(
            'Notification', 'Native device timezone channel unavailable: $e');
      }
    }

    if (nativeTzName != null && nativeTzName.isNotEmpty) {
      try {
        final loc = tz.getLocation(nativeTzName);
        tz.setLocalLocation(loc);
        AppLogger.info('Notification',
            '[SpendingNotificationService] Configured local timezone to $nativeTzName');
        return;
      } catch (e) {
        AppLogger.warning('Notification',
            'Timezone $nativeTzName not found in timezone database: $e');
      }
    }

    // Fallback: match local offset from DateTime
    try {
      final localOffset = DateTime.now().timeZoneOffset;
      tz.Location? matchedLoc;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == localOffset) {
          matchedLoc = loc;
          break;
        }
      }
      if (matchedLoc != null) {
        tz.setLocalLocation(matchedLoc);
        AppLogger.info('Notification',
            '[SpendingNotificationService] Matched local timezone ${matchedLoc.name} for offset ${localOffset.inHours}h');
        return;
      }
    } catch (_) {}

    // Safety fallback to UTC
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {}
  }

  @visibleForTesting
  void configureTimezoneForTest(String timezoneName) {
    tz.initializeTimeZones();
    final loc = tz.getLocation(timezoneName);
    tz.setLocalLocation(loc);
  }

  NotificationDetails _buildNotificationDetails(
    SpendingOverview overview,
    bool isLoggedIn,
  ) {
    final expanded = overview.expandedSummaryForLoginState(isLoggedIn);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(
        expanded,
        contentTitle: overview.notificationTitle,
        summaryText: '${overview.periodName} Spending Summary',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  // ── Test / Instant Trigger ────────────────────────────────────────────────

  /// Triggers an immediate local notification summarizing weekly spending.
  Future<void> triggerTestWeeklyNotification() async {
    final overview = getWeeklySpendingOverview();
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final title = overview.notificationTitle;
    final body = overview.notificationBodyForLoginState(isLoggedIn);
    sentNotificationIds.add(testWeeklyNotificationId);

    if (_isTestEnvironment || kIsWeb) {
      AppLogger.info(
        'Notification',
        '[Test] Instant weekly notification: $title',
      );
      return;
    }

    try {
      final details = _buildNotificationDetails(overview, isLoggedIn);
      await _notificationsPlugin.show(
        id: testWeeklyNotificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: 'test_weekly_spending',
      );
    } catch (e, st) {
      AppLogger.warning(
        'Notification',
        'Failed to send instant weekly notification: $e',
        st,
      );
    }
  }

  /// Triggers an immediate local notification summarizing monthly spending.
  Future<void> triggerTestMonthlyNotification() async {
    final overview = getMonthlySpendingOverview();
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final title = overview.notificationTitle;
    final body = overview.notificationBodyForLoginState(isLoggedIn);
    sentNotificationIds.add(testMonthlyNotificationId);

    if (_isTestEnvironment || kIsWeb) {
      AppLogger.info(
        'Notification',
        '[Test] Instant monthly notification: $title',
      );
      return;
    }

    try {
      final details = _buildNotificationDetails(overview, isLoggedIn);
      await _notificationsPlugin.show(
        id: testMonthlyNotificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: 'test_monthly_spending',
      );
    } catch (e, st) {
      AppLogger.warning(
        'Notification',
        'Failed to send instant monthly notification: $e',
        st,
      );
    }
  }
}
