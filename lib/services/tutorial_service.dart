// File: lib/services/tutorial_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger_service.dart';

/// Service managing the first-startup interactive tutorial walkthrough.
///
/// Steps:
/// 0 - Idle / Not started
/// 1 - Highlight Scan FAB on Dashboard ("Tap here to scan your first receipt")
/// 2 - Scanner guide hint banner ("Line up your receipt and tap to capture")
/// 3 - Highlight Save button on Verification screen ("Review & Save receipt")
/// 4 - Completed / Dismissed
class TutorialService extends ChangeNotifier {
  TutorialService._();
  static final TutorialService instance = TutorialService._();

  static const String _keyHasDismissedTutorial = 'has_dismissed_tutorial';

  bool _isInitialized = false;
  bool _hasDismissedTutorial = false;
  int _currentStep = 0;
  String? _scanErrorMessage;

  bool get isInitialized => _isInitialized;
  bool get hasDismissedTutorial => _hasDismissedTutorial;
  int get currentStep => _currentStep;
  bool get isActive => _currentStep >= 1 && _currentStep <= 3;
  String? get scanErrorMessage => _scanErrorMessage;

  /// Loads tutorial dismissal state from SharedPreferences.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasDismissedTutorial = prefs.getBool(_keyHasDismissedTutorial) ?? false;
      _isInitialized = true;
      AppLogger.info('TutorialService',
          'Initialized: hasDismissedTutorial=$_hasDismissedTutorial');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
          'TutorialService', 'Error initializing TutorialService', e, st);
      _isInitialized = true;
    }
  }

  /// Starts the tutorial at Step 1 (Scan FAB on Dashboard).
  void startTutorial() {
    _currentStep = 1;
    _scanErrorMessage = null;
    AppLogger.info('TutorialService', 'Started tutorial at Step 1');
    notifyListeners();
  }

  /// Advances the tutorial to the next step.
  /// If step reaches 4, automatically marks the tutorial as dismissed and completed.
  void advanceStep() {
    if (_currentStep == 0 || _currentStep >= 4) return;
    _currentStep++;
    _scanErrorMessage = null;
    AppLogger.info(
        'TutorialService', 'Advanced tutorial to Step $_currentStep');
    if (_currentStep >= 4) {
      dismissTutorial();
    } else {
      notifyListeners();
    }
  }

  /// Sets the step explicitly if needed.
  void setStep(int step) {
    if (_currentStep == step) return;
    _currentStep = step;
    _scanErrorMessage = null;
    AppLogger.info('TutorialService', 'Set tutorial to Step $_currentStep');
    if (_currentStep >= 4) {
      dismissTutorial();
    } else {
      notifyListeners();
    }
  }

  /// Called when a receipt scan fails (after retry) while in tutorial mode.
  /// Resets the tutorial back to Step 1 with a friendly error message.
  void notifyScanFailed([String? error]) {
    _currentStep = 1;
    _scanErrorMessage = error ??
        'Receipt scan failed. Please tap the scan button to try again!';
    AppLogger.warning('TutorialService',
        'Scan failed during tutorial, reset to Step 1 with error: $_scanErrorMessage');
    notifyListeners();
  }

  /// Clears any transient scan error message.
  void clearScanError() {
    if (_scanErrorMessage != null) {
      _scanErrorMessage = null;
      notifyListeners();
    }
  }

  /// Permanently marks the tutorial as dismissed/completed so it won't show again on launch.
  Future<void> dismissTutorial() async {
    _hasDismissedTutorial = true;
    _currentStep = 4;
    _scanErrorMessage = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasDismissedTutorial, true);
      AppLogger.info(
          'TutorialService', 'Tutorial dismissed and saved to prefs.');
    } catch (e, st) {
      AppLogger.error(
          'TutorialService', 'Failed to persist tutorial dismissal', e, st);
    }
    notifyListeners();
  }

  /// Resets the tutorial state for testing or when replayed from Settings.
  Future<void> resetForTesting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasDismissedTutorial);
      _hasDismissedTutorial = false;
      _currentStep = 0;
      _scanErrorMessage = null;
      AppLogger.info('TutorialService', 'Tutorial state reset.');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('TutorialService', 'Error resetting tutorial', e, st);
    }
  }
}
