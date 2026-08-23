// File: lib/ui/features/auth/views/reset_password_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../cloud/api/backend_api_client.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String resetToken;

  const ResetPasswordScreen({
    super.key,
    required this.resetToken,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final pwd = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    bool valid = true;

    String? pwdErr;
    String? confirmErr;

    if (pwd.isEmpty) {
      pwdErr = 'Password is required.';
      valid = false;
    } else if (pwd.length < 8) {
      pwdErr = 'Password must be at least 8 characters.';
      valid = false;
    } else if (!RegExp(r'[A-Z]').hasMatch(pwd)) {
      pwdErr = 'Password must contain at least one uppercase letter.';
      valid = false;
    } else if (!RegExp(r'[a-z]').hasMatch(pwd)) {
      pwdErr = 'Password must contain at least one lowercase letter.';
      valid = false;
    } else if (!RegExp(r'[0-9]').hasMatch(pwd)) {
      pwdErr = 'Password must contain at least one number.';
      valid = false;
    } else if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pwd)) {
      pwdErr = 'Password must contain at least one special character.';
      valid = false;
    }

    if (confirm.isEmpty) {
      confirmErr = 'Please confirm your password.';
      valid = false;
    } else if (pwd != confirm) {
      confirmErr = 'Passwords do not match.';
      valid = false;
    }

    setState(() {
      _passwordError = pwdErr;
      _confirmError = confirmErr;
    });

    return valid;
  }

  Future<void> _onSubmitNewPassword() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    try {
      await BackendApiClient.instance.completePasswordReset(
        resetToken: widget.resetToken,
        newPassword: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      AppSnackBar.show(
        context,
        message: 'Password reset successfully! Please log in.',
      );

      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _passwordError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _passwordError = 'Failed to reset password. Please try again.';
      });
    }
  }

  Widget _buildFieldError(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Nav Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NeumorphicIconBadge(
                      icon: Icons.arrow_back_rounded,
                      iconSize: 20,
                      onTap: () => context.pop(),
                    ),
                    Text(
                      "Set New Password",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 36),

                // Header
                Text(
                  "Create New Password",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your new password must be different from previous passwords.",
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // New Password Input
                Text(
                  "NEW PASSWORD",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                NeumorphicInputFieldWidget(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, color: textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          onChanged: (_) {
                            if (_passwordError != null)
                              setState(() => _passwordError = null);
                          },
                          decoration: InputDecoration(
                            hintText: "••••••••••••",
                            hintStyle: TextStyle(
                                color: textSecondary.withValues(alpha: 0.6),
                                fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFieldError(_passwordError),
                const SizedBox(height: 20),

                // Confirm Password Input
                Text(
                  "CONFIRM NEW PASSWORD",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                NeumorphicInputFieldWidget(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          color: textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          onChanged: (_) {
                            if (_confirmError != null)
                              setState(() => _confirmError = null);
                          },
                          decoration: InputDecoration(
                            hintText: "••••••••••••",
                            hintStyle: TextStyle(
                                color: textSecondary.withValues(alpha: 0.6),
                                fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                        child: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFieldError(_confirmError),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: NeumorphicButtonWidget(
                    onPressed: _isLoading ? null : _onSubmitNewPassword,
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              "Reset Password",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
