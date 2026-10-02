// File: lib/ui/core/widgets/two_factor_otp_sheet.dart

import 'dart:async';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../../../../cloud/api/backend_api_client.dart';

/// Modal Bottom Sheet for 2FA OTP verification across login, Google sign-in,
/// and in-app sensitive operations (enabling/disabling 2FA, password reset, account deletion).
class TwoFactorOtpSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? maskedEmail;
  final Future<void> Function(String otp) onVerify;
  final Future<void> Function()? onResend;

  const TwoFactorOtpSheet({
    super.key,
    this.title = 'Two-Factor Authentication',
    this.subtitle = 'Enter the 6-digit verification code sent to your email',
    this.maskedEmail,
    required this.onVerify,
    this.onResend,
  });

  /// Displays the modal bottom sheet and returns the verified OTP code on success, or null if dismissed.
  static Future<String?> show(
    BuildContext context, {
    String title = 'Two-Factor Authentication',
    String subtitle = 'Enter the 6-digit verification code sent to your email',
    String? maskedEmail,
    required Future<void> Function(String otp) onVerify,
    Future<void> Function()? onResend,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: TwoFactorOtpSheet(
          title: title,
          subtitle: subtitle,
          maskedEmail: maskedEmail,
          onVerify: onVerify,
          onResend: onResend,
        ),
      ),
    );
  }

  @override
  State<TwoFactorOtpSheet> createState() => _TwoFactorOtpSheetState();
}

class _TwoFactorOtpSheetState extends State<TwoFactorOtpSheet> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  // 5-minute overall code expiration timer
  int _expireCountdown = 300;
  Timer? _expireTimer;

  // 60-second resend cooldown timer
  int _resendCooldown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startExpireTimer();
    _startResendCooldownTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _resendTimer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startExpireTimer() {
    _expireTimer?.cancel();
    _expireCountdown = 300;
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_expireCountdown > 0) {
        setState(() => _expireCountdown--);
      } else {
        timer.cancel();
        setState(() {
          _errorMessage = 'Verification code has expired. Please request a new code.';
        });
      }
    });
  }

  void _startResendCooldownTimer() {
    _resendTimer?.cancel();
    _resendCooldown = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await widget.onVerify(otp);
      if (mounted) {
        Navigator.of(context).pop(otp);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = e.message.isNotEmpty ? e.message : 'Invalid verification code.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Verification failed: $e';
        });
      }
    }
  }

  Future<void> _handleResend() async {
    if (widget.onResend == null || _resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await widget.onResend!();
      if (mounted) {
        _startExpireTimer();
        _startResendCooldownTimer();
        _otpController.clear();
        setState(() {
          _isResending = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = 'Failed to resend code: $e';
        });
      }
    }
  }

  String _formatExpireDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final baseColor = controller.currentBaseColor;

    final isOtpComplete = _otpController.text.trim().length == 6;

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header icon & close button row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.shield_outlined,
                        color: accent,
                        size: 24,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle & Masked Email
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              if (widget.maskedEmail != null && widget.maskedEmail!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      widget.maskedEmail!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 6-digit numeric input
              Neumorphic(
                style: NeumorphicStyle(
                  depth: -3,
                  intensity: 0.8,
                  color: baseColor,
                  boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
                  border: NeumorphicBorder(
                    color: _errorMessage != null
                        ? Colors.redAccent.withValues(alpha: 0.6)
                        : accent.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
                child: TextField(
                  key: const Key('2fa_otp_input'),
                  controller: _otpController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 14,
                    color: textPrimary,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      letterSpacing: 14,
                      fontSize: 24,
                      color: Colors.grey,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      if (_errorMessage != null) _errorMessage = null;
                    });
                    if (val.trim().length == 6) {
                      _handleVerify();
                    }
                  },
                ),
              ),

              // Error display
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // Expiration & Resend bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Expiration countdown
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: _expireCountdown <= 60 ? Colors.redAccent : textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Expires in ${_formatExpireDuration(_expireCountdown)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _expireCountdown <= 60 ? Colors.redAccent : textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Resend Action
                  if (widget.onResend != null)
                    GestureDetector(
                      onTap: _resendCooldown == 0 && !_isResending ? _handleResend : null,
                      child: Text(
                        _isResending
                            ? 'Sending...'
                            : _resendCooldown > 0
                                ? 'Resend in ${_resendCooldown}s'
                                : 'Resend Code',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _resendCooldown == 0 && !_isResending
                              ? accent
                              : textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: NeumorphicButtonWidget(
                  key: const Key('2fa_verify_button'),
                  borderRadius: 14,
                  color: accent,
                  isLoading: _isVerifying,
                  onPressed:
                      isOtpComplete && !_isVerifying ? _handleVerify : null,
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isOtpComplete
                                  ? Colors.black
                                  : textSecondary.withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
