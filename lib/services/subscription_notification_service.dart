import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app_logger_service.dart';

/// Handles local notifications for the 14-day reverse trial:
/// 1. Immediate welcome notification upon registration.
/// 2. Scheduled expiry notification on Day 15 to inform user of downgrade and saved time.
class SubscriptionNotificationService {
  SubscriptionNotificationService._();
  static final SubscriptionNotificationService instance =
      SubscriptionNotificationService._();

  static const int trialWelcomeNotificationId = 3001;
  static const int trialExpiryNotificationId = 3002;

  static const String channelId = 'subscription_alerts';
  static const String channelName = 'Subscription & Trial Alerts';
  static const String channelDescription =
      'Important updates regarding your trial status, renewals, and plan changes.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          AppLogger.info(
            'Notification',
            'Subscription notification clicked: payload=${response.payload}',
          );
        },
      );

      if (Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
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

      _isInitialized = true;
      AppLogger.info(
        'Notification',
        'SubscriptionNotificationService initialized successfully',
      );
    } catch (e, st) {
      AppLogger.warning(
        'Notification',
        'Failed to initialize SubscriptionNotificationService: $e',
        st,
      );
    }
  }

  NotificationDetails _buildDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Sends the immediate Welcome notification upon successful registration
  Future<void> scheduleTrialWelcomeNotification() async {
    if (kIsWeb) return;
    await initialize();

    try {
      await _plugin.show(
        id: trialWelcomeNotificationId,
        title: '🎉 Premium is yours for 14 days!',
        body: 'No card needed. Enjoy lightning-fast AI scans, 50 daily allowance, and smart analytics!',
        notificationDetails: _buildDetails(),
        payload: 'trial_welcome',
      );
      AppLogger.info(
        'Notification',
        'Dispatched immediate trial welcome notification',
      );
    } catch (e) {
      AppLogger.warning(
        'Notification',
        'Failed to show trial welcome notification: $e',
      );
    }
  }

  /// Schedules the Day 15 downgrade notification at the end of the 14-day trial
  Future<void> scheduleTrialExpiryNotification(DateTime trialStartDate) async {
    if (kIsWeb) return;
    await initialize();

    // 14 full days after signup (starts on Day 15)
    final expiryDateTime = trialStartDate.add(const Duration(days: 14));
    final now = DateTime.now();

    if (expiryDateTime.isBefore(now)) {
      AppLogger.info(
        'Notification',
        'Trial expiry date $expiryDateTime has already passed, skipping schedule',
      );
      return;
    }

    try {
      final scheduledDate = tz.TZDateTime.from(expiryDateTime, tz.local);
      await _plugin.zonedSchedule(
        id: trialExpiryNotificationId,
        title: 'Your Premium trial has ended',
        body: 'You have been moved to the Free plan. All your receipts are safely preserved! Tap to see your time saved.',
        scheduledDate: scheduledDate,
        notificationDetails: _buildDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'trial_expired',
      );
      AppLogger.info(
        'Notification',
        'Scheduled Day 15 trial expiry notification for $scheduledDate',
      );
    } catch (e) {
      AppLogger.warning(
        'Notification',
        'Failed to schedule trial expiry notification: $e',
      );
    }
  }

  /// Cancel the expiry notification if user purchases a subscription beforehand
  Future<void> cancelTrialExpiryNotification() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: trialExpiryNotificationId);
      AppLogger.info('Notification', 'Cancelled trial expiry notification');
    } catch (e) {
      AppLogger.warning(
        'Notification',
        'Error cancelling trial expiry notification: $e',
      );
    }
  }
}
