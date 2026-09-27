// File: lib/ui/features/settings/views/contact_security_screen.dart

import 'dart:async';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../cloud/models/user_models.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../services/app_logger_service.dart';
import '../../../../services/sync_coordinator.dart';
import 'user_settings_screen.dart';

class ContactSecurityScreen extends StatefulWidget {
  const ContactSecurityScreen({super.key});

  @override
  State<ContactSecurityScreen> createState() => _ContactSecurityScreenState();
}

class _ContactSecurityScreenState extends State<ContactSecurityScreen> {
  UserRecordDto? _profile;
  bool get _isOnline => SyncCoordinator.instance.isOnline;

  // 2FA state (mocked locally in UI session)
  bool _is2FAEnabled = false;

  // Verification cooldown tracking
  int _verifyResendCooldownRemaining = 0;
  DateTime? _verifyCooldownStartedAt;

  @override
  void initState() {
    super.initState();
    SyncCoordinator.instance.addListener(_onSyncUpdated);
    _loadProfile();
  }

  @override
  void dispose() {
    SyncCoordinator.instance.removeListener(_onSyncUpdated);
    super.dispose();
  }

  void _onSyncUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.instance.getOrFetchProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  bool get _isPasswordCooldownActive {
    final changedAtStr =
        _profile?.preferences['password_changed_at'] as String?;
    if (changedAtStr == null) return false;
    final changedAt = DateTime.tryParse(changedAtStr);
    if (changedAt == null) return false;
    return DateTime.now().toUtc().difference(changedAt).inDays < 7;
  }

  String get _passwordCooldownMessage {
    final changedAtStr =
        _profile?.preferences['password_changed_at'] as String?;
    if (changedAtStr == null) return '';
    final changedAt = DateTime.tryParse(changedAtStr);
    if (changedAt == null) return '';
    final daysRemaining =
        7 - DateTime.now().toUtc().difference(changedAt).inDays;
    return "Password was recently changed. Change allowed in $daysRemaining day${daysRemaining == 1 ? '' : 's'}.";
  }

  Widget _buildSectionHeader(String label, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textSecondary.withValues(alpha: 0.8),
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildDivider(Color textSecondary) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: textSecondary.withValues(alpha: 0.15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        final email = _profile?.email ?? "Not configured";
        final isEmailVerified = _profile?.isEmailVerified == true;
        final hasMobile = _profile?.mobileNumber?.isNotEmpty == true;
        final countryCode = _profile?.countryCode;
        final mobileNumber = _profile?.mobileNumber;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    top: 16, bottom: 120, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar with Back Button
                    Row(
                      children: [
                        NeumorphicButton(
                          style: NeumorphicStyle(
                            shape: NeumorphicShape.flat,
                            boxShape: NeumorphicBoxShape.roundRect(
                                BorderRadius.circular(10)),
                            depth: 2.5,
                            intensity: 0.8,
                            color: NeumorphicTheme.baseColor(context),
                          ),
                          padding: const EdgeInsets.all(8),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Contact & Security",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Manage contact details and account protection",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section Header
                    _buildSectionHeader(
                        "CREDENTIALS & AUTHENTICATION", textSecondary),
                    const SizedBox(height: 8),

                    // Main Neumorphic Card with 4 Rows
                    NeumorphicCardWidget(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // 1. Email Address Row
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.email_outlined,
                                      size: 18, color: accent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "EMAIL ADDRESS",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Tooltip(
                                            message: "Edit Email Address",
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _showEditEmailBottomSheet(
                                                context: context,
                                                accent: accent,
                                                textPrimary: textPrimary,
                                                textSecondary: textSecondary,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: accent.withValues(
                                                      alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.edit_rounded,
                                                  size: 14,
                                                  color: accent,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Verification Status / Verify Button
                                if (isEmailVerified)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        "Verified",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (!_isOnline)
                                  Tooltip(
                                    message:
                                        "Email verification requires an internet connection",
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Neumorphic(
                                      style: NeumorphicStyle(
                                        depth: -2,
                                        intensity: 0.6,
                                        color: NeumorphicTheme.baseColor(
                                            context),
                                        boxShape: NeumorphicBoxShape.roundRect(
                                            BorderRadius.circular(8)),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          "Verify",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textSecondary.withValues(
                                                alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () =>
                                        _showEmailVerificationBottomSheet(
                                      context: context,
                                      email: email,
                                      accent: accent,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              accent.withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        "Verify",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _buildDivider(textSecondary),

                          // 2. Mobile Number Row
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: hasMobile
                                        ? accent.withValues(alpha: 0.12)
                                        : textSecondary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.phone_iphone_rounded,
                                    size: 18,
                                    color: hasMobile
                                        ? accent
                                        : textSecondary.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "MOBILE NUMBER",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasMobile
                                            ? "${countryCode ?? '+60'} $mobileNumber"
                                            : "Not configured",
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: hasMobile
                                              ? textPrimary
                                              : textSecondary.withValues(
                                                  alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Tooltip(
                                  message: "Coming Soon",
                                  triggerMode: TooltipTriggerMode.tap,
                                  child: Neumorphic(
                                    style: NeumorphicStyle(
                                      depth: -2,
                                      intensity: 0.6,
                                      color:
                                          NeumorphicTheme.baseColor(context),
                                      boxShape: NeumorphicBoxShape.roundRect(
                                          BorderRadius.circular(8)),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      child: Text(
                                        hasMobile ? "Edit" : "+ Add",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary.withValues(
                                              alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildDivider(textSecondary),

                          // 3. Account Password Row
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        (_isPasswordCooldownActive || !_isOnline)
                                            ? textSecondary.withValues(
                                                alpha: 0.08)
                                            : accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.lock_reset_rounded,
                                    size: 18,
                                    color:
                                        (_isPasswordCooldownActive || !_isOnline)
                                            ? textSecondary.withValues(
                                                alpha: 0.5)
                                            : accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "ACCOUNT PASSWORD",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "••••••••••••",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isOnline)
                                  Tooltip(
                                    message:
                                        "Password reset requires an internet connection",
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Neumorphic(
                                      style: NeumorphicStyle(
                                        depth: -2,
                                        boxShape: NeumorphicBoxShape.roundRect(
                                            BorderRadius.circular(8)),
                                        color: NeumorphicTheme.baseColor(
                                            context),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        child: Text(
                                          "Reset",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textSecondary.withValues(
                                                alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (_isPasswordCooldownActive)
                                  Tooltip(
                                    message: _passwordCooldownMessage,
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Neumorphic(
                                      style: NeumorphicStyle(
                                        depth: -2,
                                        boxShape: NeumorphicBoxShape.roundRect(
                                            BorderRadius.circular(8)),
                                        color: NeumorphicTheme.baseColor(
                                            context),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        child: Text(
                                          "Reset",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textSecondary.withValues(
                                                alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () =>
                                        _showChangePasswordBottomSheet(
                                      context,
                                      accent,
                                      textPrimary,
                                      textSecondary,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: accent.withValues(alpha: 0.5),
                                            width: 1),
                                        color: accent.withValues(alpha: 0.08),
                                      ),
                                      child: Text(
                                        "Reset",
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: accent),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _buildDivider(textSecondary),

                          // 4. Two-Factor Authentication (2FA) Row
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isEmailVerified
                                        ? accent.withValues(alpha: 0.12)
                                        : textSecondary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.phonelink_lock_rounded,
                                    size: 18,
                                    color: isEmailVerified
                                        ? accent
                                        : textSecondary.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "TWO-FACTOR AUTHENTICATION (2FA)",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Protect your account with an extra layer of security",
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isEmailVerified)
                                  Switch(
                                    key: const Key('2fa_switch'),
                                    value: _is2FAEnabled,
                                    activeThumbColor: accent,
                                    onChanged: (val) {
                                      setState(() => _is2FAEnabled = val);
                                      AppSnackBar.show(
                                        context,
                                        message: val
                                            ? "Two-factor authentication enabled."
                                            : "Two-factor authentication disabled.",
                                      );
                                    },
                                  )
                                else
                                  Tooltip(
                                    message:
                                        "Email verification required to enable 2FA",
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Opacity(
                                      opacity: 0.4,
                                      child: IgnorePointer(
                                        child: Switch(
                                          key: const Key('2fa_switch_disabled'),
                                          value: false,
                                          onChanged: null,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── EMAIL VERIFICATION BOTTOM SHEET ─────────────────────────────────────
  Future<void> _showEmailVerificationBottomSheet({
    required BuildContext context,
    required String email,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
  }) async {
    if (!_isOnline) {
      AppSnackBar.show(
        context,
        message: "Email verification requires an active internet connection.",
        isError: true,
      );
      return;
    }
    AppLogger.info('UI', 'User opened Email Verification modal');

    final controller = AppThemeController.instance;

    int cooldownRemaining = 0;
    if (_verifyCooldownStartedAt != null) {
      final elapsed =
          DateTime.now().difference(_verifyCooldownStartedAt!).inSeconds;
      cooldownRemaining = (60 - elapsed).clamp(0, 60);
      if (cooldownRemaining > 0) {
        _verifyResendCooldownRemaining = cooldownRemaining;
      } else {
        _verifyResendCooldownRemaining = 0;
        _verifyCooldownStartedAt = null;
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmailVerificationSheet(
        email: email,
        accent: accent,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        controller: controller,
        initialCooldownRemaining: _verifyResendCooldownRemaining,
        onCooldownStarted: (startedAt) {
          if (mounted) {
            setState(() {
              _verifyCooldownStartedAt = startedAt;
              _verifyResendCooldownRemaining = 60;
            });
          }
        },
        onVerified: (updated) {
          if (mounted) {
            setState(() {
              _profile = updated;
            });
          }
        },
      ),
    );
  }

  // ── CHANGE PASSWORD BOTTOM SHEET ────────────────────────────────────────
  void _showChangePasswordBottomSheet(
    BuildContext context,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (!_isOnline) {
      AppSnackBar.show(
        context,
        message: "Password reset requires an active internet connection.",
        isError: true,
      );
      return;
    }
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final newPass = newPasswordController.text;
            final confirmPass = confirmPasswordController.text;

            final hasMinLen = newPass.length >= 8;
            final hasUpper = RegExp(r'[A-Z]').hasMatch(newPass);
            final hasLower = RegExp(r'[a-z]').hasMatch(newPass);
            final hasDigit = RegExp(r'[0-9]').hasMatch(newPass);
            final hasSpecial =
                RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(newPass);
            final isStrong =
                hasMinLen && hasUpper && hasLower && hasDigit && hasSpecial;

            return Container(
              decoration: BoxDecoration(
                color: NeumorphicTheme.baseColor(modalCtx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Reset Account Password",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: textSecondary, size: 20),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "CURRENT PASSWORD",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    NeumorphicInputFieldWidget(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Enter current password",
                          hintStyle: TextStyle(
                              color: textSecondary.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureOld
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: textSecondary,
                              size: 18,
                            ),
                            onPressed: () =>
                                setModalState(() => obscureOld = !obscureOld),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "NEW PASSWORD",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    NeumorphicInputFieldWidget(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        onChanged: (_) => setModalState(() => errorMsg = null),
                        decoration: InputDecoration(
                          hintText: "Enter new password",
                          hintStyle: TextStyle(
                              color: textSecondary.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: textSecondary,
                              size: 18,
                            ),
                            onPressed: () =>
                                setModalState(() => obscureNew = !obscureNew),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildRequirementChip("8+ chars", hasMinLen, accent,
                            textPrimary, textSecondary),
                        _buildRequirementChip("Upper", hasUpper, accent,
                            textPrimary, textSecondary),
                        _buildRequirementChip("Lower", hasLower, accent,
                            textPrimary, textSecondary),
                        _buildRequirementChip("Digit", hasDigit, accent,
                            textPrimary, textSecondary),
                        _buildRequirementChip("Special", hasSpecial, accent,
                            textPrimary, textSecondary),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "CONFIRM NEW PASSWORD",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    NeumorphicInputFieldWidget(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        onChanged: (_) => setModalState(() => errorMsg = null),
                        decoration: InputDecoration(
                          hintText: "Re-enter new password",
                          hintStyle: TextStyle(
                              color: textSecondary.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: textSecondary,
                              size: 18,
                            ),
                            onPressed: () => setModalState(
                                () => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: NeumorphicButton(
                        style: NeumorphicStyle(
                          depth: (isStrong && !isSubmitting) ? 3 : -1,
                          color: (isStrong && !isSubmitting)
                              ? accent
                              : NeumorphicTheme.baseColor(modalCtx),
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                        ),
                        onPressed: (isStrong && !isSubmitting)
                            ? () async {
                                if (newPass != confirmPass) {
                                  setModalState(() => errorMsg =
                                      "New passwords do not match.");
                                  return;
                                }
                                setModalState(() {
                                  isSubmitting = true;
                                  errorMsg = null;
                                });
                                try {
                                  await AuthService.instance.changePassword(
                                    oldPassword:
                                        oldPasswordController.text.trim(),
                                    newPassword:
                                        newPasswordController.text.trim(),
                                  );
                                  if (modalCtx.mounted) {
                                    Navigator.of(modalCtx).pop();
                                  }
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      message:
                                          "Password updated successfully.",
                                    );
                                  }
                                  await _loadProfile();
                                } on ApiException catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMsg = e.message.isNotEmpty
                                        ? e.message
                                        : "Failed to update password.";
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMsg = "An error occurred: $e";
                                  });
                                }
                              }
                            : null,
                        child: Center(
                          child: isSubmitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                )
                              : Text(
                                  "Update Password",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isStrong
                                        ? Colors.black
                                        : textSecondary.withValues(alpha: 0.5),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequirementChip(String label, bool met, Color accent,
      Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: met
            ? accent.withValues(alpha: 0.15)
            : textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: met
              ? accent.withValues(alpha: 0.4)
              : textSecondary.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_rounded : Icons.close_rounded,
            size: 11,
            color: met ? accent : textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: met ? textPrimary : textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── EDIT EMAIL BOTTOM SHEET ─────────────────────────────────────────────
  Future<void> _showEditEmailBottomSheet({
    required BuildContext context,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
  }) async {
    AppLogger.info('UI', 'User opened Edit Email modal');
    final initialEmail = _profile?.email ?? "";
    final emailController = TextEditingController(text: initialEmail);
    bool isSaving = false;
    String? emailError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeumorphicTheme.baseColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentClean = emailController.text.trim();
            final isEmailChanged = currentClean.isNotEmpty &&
                currentClean.toLowerCase() != initialEmail.trim().toLowerCase();

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Change Email Address",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Enter your new email address below.",
                                style: TextStyle(
                                    fontSize: 13, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: textSecondary, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "NEW EMAIL ADDRESS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    NeumorphicInputFieldWidget(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        onChanged: (val) {
                          setModalState(() {
                            emailError = null;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Enter email address",
                          hintStyle: TextStyle(
                              color: textSecondary.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          isDense: true,
                          prefixIcon: Icon(Icons.email_outlined,
                              size: 18, color: accent),
                          prefixIconConstraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                      ),
                    ),
                    if (emailError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        emailError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Save Changes Button
                    SizedBox(
                      width: double.infinity,
                      child: (isEmailChanged && !isSaving)
                          ? NeumorphicButton(
                              style: NeumorphicStyle(
                                depth: 3,
                                color: accent,
                                boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                final clean = emailController.text.trim();
                                final emailRegExp = RegExp(
                                    r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
                                if (!emailRegExp.hasMatch(clean)) {
                                  setModalState(() {
                                    emailError =
                                        "Please enter a valid email address.";
                                  });
                                  return;
                                }
                                _showEmailChangeConfirmationDialog(
                                  context: context,
                                  newEmail: clean,
                                  accent: accent,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  onConfirm: () async {
                                    try {
                                      setModalState(() => isSaving = true);
                                      final updated = await AuthService.instance
                                          .updateEmail(clean);
                                      if (context.mounted) {
                                        setState(() {
                                          _profile = updated;
                                        });
                                        if (ctx.mounted) Navigator.of(ctx).pop();
                                        AppSnackBar.show(
                                          context,
                                          message:
                                              "Email updated. Please verify your new email address.",
                                        );
                                      }
                                    } on RateLimitException catch (_) {
                                      if (ctx.mounted) Navigator.of(ctx).pop();
                                      if (context.mounted) {
                                        AppSnackBar.show(
                                          context,
                                          message:
                                              "Please wait and try again later",
                                          isError: true,
                                        );
                                      }
                                    } on ApiException catch (e) {
                                      if (ctx.mounted) Navigator.of(ctx).pop();
                                      if (context.mounted) {
                                        final msg = e.statusCode == 429
                                            ? "Please wait and try again later"
                                            : (e.statusCode == 409
                                                ? (e.message.isNotEmpty
                                                    ? e.message
                                                    : "An account with this email already exists.")
                                                : (e.message.isNotEmpty
                                                    ? e.message
                                                    : "Failed to update email."));
                                        AppSnackBar.show(
                                          context,
                                          message: msg,
                                          isError: true,
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        AppSnackBar.show(
                                          context,
                                          message:
                                              "Error updating email: $e",
                                          isError: true,
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setModalState(() => isSaving = false);
                                      }
                                    }
                                  },
                                );
                              },
                              child: const Center(
                                child: Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            )
                          : Neumorphic(
                              style: NeumorphicStyle(
                                depth: -2.5,
                                intensity: 0.7,
                                boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(12)),
                                color: NeumorphicTheme.baseColor(context),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: isSaving
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  accent),
                                        ),
                                      )
                                    : Text(
                                        "Save Changes",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary.withValues(
                                              alpha: 0.35),
                                        ),
                                      ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── EMAIL CHANGE CONFIRMATION DIALOG ────────────────────────────────────
  Future<void> _showEmailChangeConfirmationDialog({
    required BuildContext context,
    required String newEmail,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Future<void> Function() onConfirm,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: NeumorphicTheme.baseColor(context),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Change Email Address?",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Are you sure you want to change your email to:",
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    newEmail,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "• Your verification status will be reset, requiring you to verify this new email.\n• Contact details can only be changed once every 5 minutes.",
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: textSecondary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                            color: textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await onConfirm();
                      },
                      child: const Text(
                        "Confirm & Update",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
