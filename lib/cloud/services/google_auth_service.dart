import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/repositories/chat_message_repository.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/receipt_repository.dart';
import '../../services/app_logger_service.dart';
import '../../services/category_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/data_export_service.dart';
import '../../services/device_identity_service.dart';
import '../../services/local_image_cache_service.dart';
import '../../services/subscription_notification_service.dart';
import '../api/api_config.dart';
import '../api/backend_api_client.dart';
import '../models/user_models.dart';
import 'auth_service.dart';
import '../../ui/core/widgets/app_snack_bar.dart';
import '../../ui/core/widgets/two_factor_otp_sheet.dart';
import '../../ui/features/auth/widgets/google_username_prompt_sheet.dart';
import '../../ui/features/auth/widgets/guest_override_warning_modal.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _client {
    return _googleSignIn ??= GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: ApiConfig.googleServerClientId.isNotEmpty
          ? ApiConfig.googleServerClientId
          : null,
    );
  }

  /// Initiates native Google Sign-In flow and exchanges ID Token with the backend.
  Future<void> signInWithGoogle(
    BuildContext context, {
    void Function(bool isLoading)? onLoadingChanged,
  }) async {
    onLoadingChanged?.call(true);
    AppLogger.info('GoogleAuth', 'Starting Google Sign-In flow...');

    try {
      // 0. Force account picker dialog by clearing any cached Google session
      try {
        await _client.signOut();
      } catch (e) {
        AppLogger.warning('GoogleAuth', 'Pre-sign-in signOut non-fatal error: $e');
      }

      // 1. Prompt native Google account selection
      final GoogleSignInAccount? account = await _client.signIn();
      if (account == null) {
        AppLogger.info('GoogleAuth', 'User dismissed Google Sign-In dialog');
        onLoadingChanged?.call(false);
        return;
      }

      AppLogger.info(
          'GoogleAuth', 'Google account selected: ${account.email}');

      // 2. Obtain ID Token
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          'Google Sign-In did not return an identity token. Please ensure Google Play Services is up to date.',
          statusCode: 400,
        );
      }

      // Check if local unsynced guest data exists on the device
      final guestData = await DataExportService.instance.exportGuestData();
      final hasGuestData = (guestData['receipts'] as List).isNotEmpty ||
          (guestData['conversations'] as List).isNotEmpty ||
          (guestData['chat_messages'] as List).isNotEmpty ||
          (guestData['custom_categories'] as List).isNotEmpty;

      // 3. Exchange ID Token with backend
      Map<String, dynamic> res = await BackendApiClient.instance.googleAuth(
        idToken: idToken,
        preferences: {
          'trial_device_id': DeviceIdentityService.instance.deviceId,
        },
      );

      // Handle Two-Factor Authentication (2FA) Challenge
      if (res['requires_2fa'] == true) {
        onLoadingChanged?.call(false);
        if (!context.mounted) return;

        final tempToken = res['temp_token'] as String?;
        final maskedEmail = res['masked_email'] as String?;

        if (tempToken == null) {
          throw const ApiException('Invalid 2FA challenge response from backend.',
              statusCode: 500);
        }

        UserLoginResponseDto? verifiedResponse;
        await TwoFactorOtpSheet.show(
          context,
          title: 'Two-Factor Authentication',
          subtitle: 'Enter the 6-digit verification code sent to your email',
          maskedEmail: maskedEmail,
          onVerify: (otp) async {
            final vfy = await BackendApiClient.instance.login2faVerify(
              tempToken: tempToken,
              otp: otp,
            );
            verifiedResponse = vfy;
          },
          onResend: () async {
            await BackendApiClient.instance.login2faResend(
              tempToken: tempToken,
            );
          },
        );

        if (verifiedResponse == null || verifiedResponse!.user == null) {
          AppLogger.info('GoogleAuth', 'User canceled or failed 2FA verification');
          return;
        }

        onLoadingChanged?.call(true);
        final user = verifiedResponse!.user!;
        final accessToken = verifiedResponse!.accessToken;
        final refreshToken = verifiedResponse!.refreshToken;

        if (!context.mounted) return;
        await _handleReturningUserLogin(
          context: context,
          user: user,
          accessToken: accessToken,
          refreshToken: refreshToken,
          hasGuestData: hasGuestData,
          onLoadingChanged: onLoadingChanged,
        );
        return;
      }

      // 4. Handle first-time registration requiring username selection
      if (res['needs_username'] == true) {
        onLoadingChanged?.call(false);

        if (!context.mounted) return;

        final chosenUsername = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => GoogleUsernamePromptSheet(
            suggestedUsername: res['suggested_username'] as String? ?? '',
            email: res['email'] as String? ?? account.email,
          ),
        );

        if (chosenUsername == null || chosenUsername.isEmpty) {
          AppLogger.info('GoogleAuth', 'User canceled username selection modal');
          return;
        }

        onLoadingChanged?.call(true);

        // Submit chosen username
        res = await BackendApiClient.instance.googleAuth(
          idToken: idToken,
          username: chosenUsername,
          preferences: {
            'trial_device_id': DeviceIdentityService.instance.deviceId,
          },
        );
      }

      // 5. Complete session setup
      final userMap = res['user'] as Map<String, dynamic>?;
      if (userMap == null) {
        throw const ApiException('Invalid response structure from backend.',
            statusCode: 500);
      }

      final user = UserRecordDto.fromJson(userMap);
      final accessToken = res['access_token'] as String?;
      final refreshToken = res['refresh_token'] as String?;
      final isNewUser = res['is_new_user'] == true;

      if (!context.mounted) return;

      if (isNewUser) {
        await _handleNewUserRegistration(
          context: context,
          user: user,
          accessToken: accessToken,
          refreshToken: refreshToken,
          hasGuestData: hasGuestData,
          guestData: guestData,
        );
      } else {
        await _handleReturningUserLogin(
          context: context,
          user: user,
          accessToken: accessToken,
          refreshToken: refreshToken,
          hasGuestData: hasGuestData,
          onLoadingChanged: onLoadingChanged,
        );
      }
    } on ApiException catch (e) {
      AppLogger.warning(
          'GoogleAuth', 'ApiException during Google Auth: ${e.statusCode} - ${e.message}');
      if (!context.mounted) return;

      if (e.statusCode == 409 &&
          e.message.toLowerCase().contains('email already in use')) {
        AppSnackBar.show(
          context,
          message: 'Email already in use.',
          isError: true,
        );
      } else {
        AppSnackBar.show(
          context,
          message: e.message.isNotEmpty ? e.message : 'Google authentication failed.',
          isError: true,
        );
      }
    } on PlatformException catch (e, st) {
      if (e.code == 'sign_in_failed' && (e.message?.contains('10') ?? false)) {
        AppLogger.error(
          'GoogleAuth',
          'Google Sign-In DEVELOPER_ERROR (code 10). Missing or mismatched Android OAuth Client ID in Google Cloud Console.\n'
          'Ensure Package: org.effoc.sancfund\n'
          'Keystore SHA-1: 6F:12:23:8E:9D:B0:8F:20:B1:CE:F5:48:74:C5:32:D5:32:24:CE:3F',
          e,
          st,
        );
      } else {
        AppLogger.error(
            'GoogleAuth', 'PlatformException during Google Sign-In: ${e.code}', e, st);
      }
      try {
        await _client.signOut();
      } catch (_) {}
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: 'Unable to connect to Google. Please try again.',
        isError: true,
      );
    } catch (e, st) {
      AppLogger.error('GoogleAuth', 'Unexpected error during Google Auth', e, st);
      try {
        await _client.signOut();
      } catch (_) {}
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: 'Unable to connect to Google. Please try again.',
        isError: true,
      );
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  Future<void> _handleNewUserRegistration({
    required BuildContext context,
    required UserRecordDto user,
    required String? accessToken,
    required String? refreshToken,
    required bool hasGuestData,
    required Map<String, dynamic> guestData,
  }) async {
    await AuthService.instance.saveSession(
      user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    // Link device and atomically migrate guest data to Supabase
    await AuthService.instance.linkCurrentDevice(
      user,
      migrateData: hasGuestData ? guestData : null,
    );

    // Purge local temporary guest stores (they now live in Supabase)
    await _purgeLocalGuestData();

    // Force re-fetch profile so custom categories and avatar path load
    await AuthService.instance.getOrFetchProfile(force: true);

    // Prime local avatar cache from Supabase Storage
    unawaited(LocalImageCacheService.instance
        .getOrFetchAvatar(size: 'medium', forceRefresh: true));

    // Pull down migrated receipts with their cloud UUIDs
    await CloudSyncService.instance.syncOnLogin();

    // 14-day trial & notifications
    final isTrial =
        user.tier == 'premium' || (user.preferences['is_in_trial'] == true);
    if (isTrial) {
      await DeviceIdentityService.instance.markTrialUsed();
      final trialStartStr = user.preferences['trial_start_at'] as String?;
      final trialStart = trialStartStr != null
          ? (DateTime.tryParse(trialStartStr) ?? DateTime.now())
          : DateTime.now();
      unawaited(SubscriptionNotificationService.instance
          .scheduleTrialWelcomeNotification());
      unawaited(SubscriptionNotificationService.instance
          .scheduleTrialExpiryNotification(trialStart));
    }

    AppLogger.info(
        'GoogleAuth', 'Google registration & migration succeeded for user: ${user.username}');

    if (!context.mounted) return;

    AppSnackBar.show(
      context,
      message: 'Account created! Welcome, ${user.username}!',
    );

    if (isTrial) {
      context.go('/dashboard');
      context.push('/user-settings?highlight=plan');
    } else {
      context.go('/dashboard');
    }
  }

  Future<void> _handleReturningUserLogin({
    required BuildContext context,
    required UserRecordDto user,
    required String? accessToken,
    required String? refreshToken,
    required bool hasGuestData,
    void Function(bool isLoading)? onLoadingChanged,
  }) async {
    if (hasGuestData) {
      onLoadingChanged?.call(false);
      AppLogger.info('GoogleAuth',
          'Local guest data detected on existing user login. Prompting override warning modal...');
      if (!context.mounted) return;
      final confirmed = await showGuestOverrideWarningModal(context);
      if (!confirmed) {
        AppLogger.info(
            'GoogleAuth', 'User canceled override modal. Aborting Google login.');
        await signOut();
        return;
      }
      onLoadingChanged?.call(true);
      await _purgeLocalGuestData();
    } else {
      await _purgeLocalGuestData();
    }

    await AuthService.instance.saveSession(
      user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    unawaited(AuthService.instance
        .linkCurrentDevice(user)
        .then((_) => CloudSyncService.instance.syncOnLogin())
        .catchError((e, st) {
      AppLogger.error(
          'CloudSync', 'Background link/sync error post-Google login', e, st);
    }));

    unawaited(LocalImageCacheService.instance
        .getOrFetchAvatar(size: 'medium'));

    AppLogger.info(
        'GoogleAuth', 'Google login succeeded for user: ${user.username}');

    if (!context.mounted) return;

    AppSnackBar.show(
      context,
      message: 'Welcome back, ${user.username}!',
    );

    context.go('/dashboard');
  }

  /// Purges local guest-mode data stores.
  Future<void> _purgeLocalGuestData() async {
    AppLogger.info('GoogleAuth', 'Purging local temporary guest data stores...');
    await ReceiptRepository.instance.clearAll();
    await ConversationRepository.instance.clearAll();
    await ChatMessageRepository.instance.clearAll();
    await CategoryService.instance.clearAll();
  }

  /// Disconnects cached Google account credentials on logout.
  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (e) {
      AppLogger.warning('GoogleAuth', 'Error signing out of Google: $e');
    }
  }
}
