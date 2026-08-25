import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger_service.dart';

/// Service managing first-launch onboarding walkthrough and legal terms consent state.
class OnboardingService extends ChangeNotifier {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  static const String _keyHasCompletedOnboarding = 'has_completed_onboarding';
  static const String _keyHasAcceptedLegalTerms = 'has_accepted_legal_terms';
  static const String _keyLegalTermsAcceptedVersion =
      'legal_terms_accepted_version';
  static const String _keyLegalTermsAcceptedAt = 'legal_terms_accepted_at';

  static const String currentLegalVersion = '1.0.0 (2026-08-25)';

  bool _isInitialized = false;
  bool _hasCompletedOnboarding = false;
  bool _hasAcceptedLegalTerms = false;
  String? _legalTermsAcceptedVersion;
  String? _legalTermsAcceptedAt;

  bool get isInitialized => _isInitialized;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get hasAcceptedLegalTerms => _hasAcceptedLegalTerms;
  String? get legalTermsAcceptedVersion => _legalTermsAcceptedVersion;
  String? get legalTermsAcceptedAt => _legalTermsAcceptedAt;

  /// Loads onboarding and legal consent state from SharedPreferences.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasCompletedOnboarding =
          prefs.getBool(_keyHasCompletedOnboarding) ?? false;
      _hasAcceptedLegalTerms =
          prefs.getBool(_keyHasAcceptedLegalTerms) ?? false;
      _legalTermsAcceptedVersion =
          prefs.getString(_keyLegalTermsAcceptedVersion);
      _legalTermsAcceptedAt = prefs.getString(_keyLegalTermsAcceptedAt);

      _isInitialized = true;
      AppLogger.info('OnboardingService',
          'Initialized: completed=$_hasCompletedOnboarding, legalAccepted=$_hasAcceptedLegalTerms (version: $_legalTermsAcceptedVersion)');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
          'OnboardingService', 'Error initializing OnboardingService', e, st);
      _isInitialized = true;
    }
  }

  /// Marks onboarding as complete and records timestamped legal agreement.
  Future<void> completeOnboarding({bool acceptLegal = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasCompletedOnboarding = true;
      await prefs.setBool(_keyHasCompletedOnboarding, true);

      if (acceptLegal) {
        _hasAcceptedLegalTerms = true;
        _legalTermsAcceptedVersion = currentLegalVersion;
        _legalTermsAcceptedAt = DateTime.now().toUtc().toIso8601String();

        await prefs.setBool(_keyHasAcceptedLegalTerms, true);
        await prefs.setString(
            _keyLegalTermsAcceptedVersion, currentLegalVersion);
        await prefs.setString(_keyLegalTermsAcceptedAt, _legalTermsAcceptedAt!);
      }

      AppLogger.info('OnboardingService',
          'Onboarding completed successfully. Legal consent recorded: $_hasAcceptedLegalTerms at $_legalTermsAcceptedAt');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
          'OnboardingService', 'Failed to complete onboarding', e, st);
    }
  }

  /// Resets onboarding status for QA testing or manual re-take.
  Future<void> resetForTesting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasCompletedOnboarding);
      await prefs.remove(_keyHasAcceptedLegalTerms);
      await prefs.remove(_keyLegalTermsAcceptedVersion);
      await prefs.remove(_keyLegalTermsAcceptedAt);

      _hasCompletedOnboarding = false;
      _hasAcceptedLegalTerms = false;
      _legalTermsAcceptedVersion = null;
      _legalTermsAcceptedAt = null;

      AppLogger.info('OnboardingService', 'Onboarding state reset.');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('OnboardingService', 'Error resetting onboarding', e, st);
    }
  }
}
