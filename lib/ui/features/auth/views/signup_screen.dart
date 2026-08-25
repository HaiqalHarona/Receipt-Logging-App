// File: lib/ui/features/auth/views/signup_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../data/repositories/chat_message_repository.dart';
import '../../../../services/category_service.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../services/data_export_service.dart';
import '../../../../services/app_logger_service.dart';
import '../../../../cloud/api/api_config.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Inline field-level error states
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    AppLogger.info('UI', 'SignUpScreen initialized');
    if (AuthService.instance.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard');
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── VALIDATION ──────────────────────────────────────────────────────────────

  bool _validateFields() {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    bool valid = true;

    String? usernameErr;
    String? emailErr;
    String? passwordErr;
    String? confirmErr;

    if (username.isEmpty) {
      usernameErr = 'Username is required.';
      valid = false;
    } else if (!RegExp(r'^[a-zA-Z0-9_]{3,10}$').hasMatch(username)) {
      usernameErr =
          'Username must be 3-10 characters (letters, numbers, underscores only).';
      valid = false;
    }

    if (email.isEmpty) {
      emailErr = 'Email address is required.';
      valid = false;
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailErr = 'Please enter a valid email address.';
      valid = false;
    }

    if (password.isEmpty) {
      passwordErr = 'Password is required.';
      valid = false;
    } else if (password.length < 8) {
      passwordErr = 'Password must be at least 8 characters.';
      valid = false;
    } else if (!RegExp(r'[A-Z]').hasMatch(password)) {
      passwordErr = 'Password must contain at least one uppercase letter.';
      valid = false;
    } else if (!RegExp(r'[a-z]').hasMatch(password)) {
      passwordErr = 'Password must contain at least one lowercase letter.';
      valid = false;
    } else if (!RegExp(r'[0-9]').hasMatch(password)) {
      passwordErr = 'Password must contain at least one number.';
      valid = false;
    } else if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      passwordErr = 'Password must contain at least one special character.';
      valid = false;
    }

    if (confirmPassword.isEmpty) {
      confirmErr = 'Please confirm your password.';
      valid = false;
    } else if (password != confirmPassword) {
      confirmErr = 'Passwords do not match.';
      valid = false;
    }

    setState(() {
      _usernameError = usernameErr;
      _emailError = emailErr;
      _passwordError = passwordErr;
      _confirmPasswordError = confirmErr;
    });

    if (!valid) {
      AppLogger.warning('UI', 'SignUp validation failed');
    }

    return valid;
  }

  // ── SIGN UP HANDLER ─────────────────────────────────────────────────────────

  Future<void> _onSignUp() async {
    AppLogger.info('UI', 'User tapped Sign Up button');
    if (!_validateFields()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      // Export guest data before creating the account so we have the payload
      // ready to pass to linkDevice — migration happens atomically on linking.
      final guestData = await DataExportService.instance.exportGuestData();
      final hasGuestData = (guestData['receipts'] as List).isNotEmpty ||
          (guestData['conversations'] as List).isNotEmpty ||
          (guestData['chat_messages'] as List).isNotEmpty ||
          (guestData['custom_categories'] as List).isNotEmpty;

      final user = await BackendApiClient.instance.createUser(
        username: username,
        email: email,
        password: password,
      );

      // Obtain signed JWT session tokens
      final loginResp = await BackendApiClient.instance.loginUser(
        username: username,
        password: password,
      );

      // Auto login: persist session and link hardware device
      // Pass migrateData only when there is actual guest data to migrate.
      await AuthService.instance.saveSession(
        user,
        accessToken: loginResp.accessToken,
        refreshToken: loginResp.refreshToken,
      );
      await AuthService.instance.linkCurrentDevice(
        user,
        migrateData: hasGuestData ? guestData : null,
      );

      // Once migration to Supabase succeeds:
      // 1. Purge local temporary guest stores (they now live in Supabase)
      await ReceiptRepository.instance.clearAll();
      await ConversationRepository.instance.clearAll();
      await ChatMessageRepository.instance.clearAll();
      await CategoryService.instance.clearAll();

      // 2. Force re-fetch profile so migrated custom categories load into CategoryService
      await AuthService.instance.getOrFetchProfile(force: true);

      // 3. Trigger initial cloud sync to download migrated receipts with Supabase UUIDs
      await CloudSyncService.instance.syncOnLogin();

      if (!mounted) return;
      setState(() => _isLoading = false);

      AppLogger.info('UI', 'Account created successfully for ${user.username}');

      AppSnackBar.show(
        context,
        message: 'Account created! Welcome, ${user.username}!',
      );

      // Navigate to dashboard, clearing the auth stack
      context.go('/dashboard');
    } on ApiException catch (e) {
      setState(() => _isLoading = false);

      final detail = e.message.toLowerCase();
      if (detail.contains('username')) {
        setState(() => _usernameError = 'This username is already taken.');
      } else if (detail.contains('email')) {
        setState(
            () => _emailError = 'An account with this email already exists.');
      } else {
        // Fallback: surface the server message as a username error
        setState(() => _usernameError = e.message);
      }
      AppLogger.error(
          'UI', 'SignUp ApiException: ${e.statusCode} - ${e.message}', e);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Unable to connect. Please check your internet connection.',
          isError: true,
        );
      }
      AppLogger.error('UI', 'SignUp unexpected error: $e', e);
    }
  }

  // ── PASSWORD STRENGTH HELPER ─────────────────────────────────────────────

  int _calculatePasswordStrength(String pass) {
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 6) score++;
    if (pass.length >= 8 && RegExp(r'[0-9]').hasMatch(pass)) score++;
    if (RegExp(r'[A-Z]').hasMatch(pass) && RegExp(r'[a-z]').hasMatch(pass))
      score++;
    if (RegExp(r'[!@#\$&*~-]').hasMatch(pass) || pass.length >= 12) score++;
    return score.clamp(1, 4);
  }

  Color _getPasswordStrengthColor(int strength, Color accent) {
    switch (strength) {
      case 1:
        return Colors.redAccent;
      case 2:
        return Colors.orangeAccent;
      case 3:
        return Colors.amber;
      case 4:
        return accent;
      default:
        return Colors.transparent;
    }
  }

  String _getPasswordStrengthLabel(int strength) {
    switch (strength) {
      case 1:
        return "Weak (min 6 characters)";
      case 2:
        return "Fair (add numbers & mix case)";
      case 3:
        return "Good";
      case 4:
        return "Strong";
      default:
        return "";
    }
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────────

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

  Widget _buildSectionLabel(String label, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
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

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final passText = _passwordController.text;
    final strength = _calculatePasswordStrength(passText);

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Back Pill
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        AppLogger.info(
                            'UI', 'User tapped Back on SignUpScreen');
                        if (GoRouter.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.go('/auth');
                        }
                      },
                      child: Neumorphic(
                        style: NeumorphicStyle(
                          depth: 4,
                          intensity: 0.85,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                          color: controller.currentBaseColor,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_rounded,
                                  color: textPrimary, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "Back",
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Welcome Header
                Text(
                  "Create ${ApiConfig.appName} Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Sign up to ${ApiConfig.appName} to start tracking and managing your expenses",
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Visual Progress Stepper ──────────────────────────────────
                Row(
                  children: [
                    _buildStepperPill(
                        "1. Account", true, accent, textSecondary),
                    const SizedBox(width: 6),
                    _buildStepperPill("2. Security", passText.isNotEmpty,
                        accent, textSecondary),
                    const SizedBox(width: 6),
                    _buildStepperPill(
                        "3. Complete", false, accent, textSecondary),
                  ],
                ),
                const SizedBox(height: 28),

                // ── SECTION 1: ACCOUNT INFORMATION ────────────────────────────
                _buildSectionLabel("ACCOUNT INFORMATION", textSecondary),
                NeumorphicCardWidget(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username Input
                      Row(
                        children: [
                          Icon(Icons.person_rounded,
                              color: textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              style:
                                  TextStyle(color: textPrimary, fontSize: 14),
                              autocorrect: false,
                              onChanged: (_) {
                                if (_usernameError != null) {
                                  setState(() => _usernameError = null);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: "Choose a username",
                                hintStyle: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.6),
                                    fontSize: 14),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        height: 16,
                        thickness: 0.5,
                        color: textSecondary.withValues(alpha: 0.15),
                      ),
                      // Email Input
                      Row(
                        children: [
                          Icon(Icons.email_rounded,
                              color: textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style:
                                  TextStyle(color: textPrimary, fontSize: 14),
                              autocorrect: false,
                              onChanged: (_) {
                                if (_emailError != null) {
                                  setState(() => _emailError = null);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: "user@example.com",
                                hintStyle: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.6),
                                    fontSize: 14),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildFieldError(_usernameError),
                _buildFieldError(_emailError),
                const SizedBox(height: 24),

                // ── SECTION 2: SECURITY CREDENTIALS ───────────────────────────
                _buildSectionLabel("SECURITY CREDENTIALS", textSecondary),
                NeumorphicCardWidget(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Password Input
                      Row(
                        children: [
                          Icon(Icons.lock_rounded,
                              color: textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style:
                                  TextStyle(color: textPrimary, fontSize: 14),
                              onChanged: (_) {
                                setState(() {
                                  if (_passwordError != null)
                                    _passwordError = null;
                                  if (_confirmPasswordError != null) {
                                    _confirmPasswordError = null;
                                  }
                                });
                              },
                              decoration: InputDecoration(
                                hintText: "Password (min 6 characters)",
                                hintStyle: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.6),
                                    fontSize: 14),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
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

                      // Password Strength Indicator Bar
                      if (passText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(4, (index) {
                            final isActive = index < strength;
                            final color =
                                _getPasswordStrengthColor(strength, accent);
                            return Expanded(
                              child: Container(
                                height: 3.5,
                                margin: EdgeInsets.only(
                                    left: index == 0 ? 0 : 4,
                                    right: index == 3 ? 0 : 4),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? color
                                      : textSecondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getPasswordStrengthLabel(strength),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _getPasswordStrengthColor(strength, accent),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      Divider(
                        height: 16,
                        thickness: 0.5,
                        color: textSecondary.withValues(alpha: 0.15),
                      ),

                      // Confirm Password Input
                      Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              color: textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style:
                                  TextStyle(color: textPrimary, fontSize: 14),
                              onChanged: (_) {
                                if (_confirmPasswordError != null) {
                                  setState(() => _confirmPasswordError = null);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: "Confirm your password",
                                hintStyle: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.6),
                                    fontSize: 14),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
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
                    ],
                  ),
                ),
                _buildFieldError(_passwordError),
                _buildFieldError(_confirmPasswordError),
                const SizedBox(height: 32),

                // ── Create Account CTA Button ─────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: NeumorphicButtonWidget(
                    onPressed: _isLoading ? null : _onSignUp,
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Create Account",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Legal Terms Disclaimer ──────────────────────────────────
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "By creating an account, you agree to our ",
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary.withValues(alpha: 0.85),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/legal/terms'),
                          child: Text(
                            "Terms of Service",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accent,
                              decoration: TextDecoration.underline,
                              decorationColor: accent,
                            ),
                          ),
                        ),
                        Text(
                          " and ",
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary.withValues(alpha: 0.85),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/legal/privacy'),
                          child: Text(
                            "Privacy Policy",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accent,
                              decoration: TextDecoration.underline,
                              decorationColor: accent,
                            ),
                          ),
                        ),
                        Text(
                          ".",
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Centered Log In Link ──────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () {
                      AppLogger.info(
                          'UI', 'User tapped Log In link on SignUpScreen');
                      if (GoRouter.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go('/login');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: RichText(
                        text: TextSpan(
                          style:
                              TextStyle(fontSize: 13.5, color: textSecondary),
                          children: [
                            const TextSpan(text: "Already have an account? "),
                            TextSpan(
                              text: "Log In",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accent,
                                decoration: TextDecoration.underline,
                                decorationColor: accent,
                              ),
                            ),
                          ],
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

  Widget _buildStepperPill(
      String label, bool isActive, Color accent, Color textSecondary) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: 0.15)
              : textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isActive ? accent.withValues(alpha: 0.35) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? accent : textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
