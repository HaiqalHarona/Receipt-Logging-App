// File: lib/ui/features/auth/views/signup_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

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
    } else if (username.length < 3) {
      usernameErr = 'Username must be at least 3 characters.';
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
    } else if (password.length < 6) {
      passwordErr = 'Password must be at least 6 characters.';
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

    return valid;
  }

  // ── SIGN UP HANDLER ─────────────────────────────────────────────────────────

  Future<void> _onSignUp() async {
    if (!_validateFields()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final user = await BackendApiClient.instance.createUser(
        username: username,
        email: email,
        password: password,
      );

      // Auto login: persist session and link hardware device
      await AuthService.instance.saveSession(user, userToken: password);
      await AuthService.instance.linkCurrentDevice(user, userToken: password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created! Welcome, ${user.username}!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );

      // Navigate to dashboard, clearing the auth stack
      context.go('/dashboard');
    } on ApiException catch (e) {
      setState(() => _isLoading = false);

      final detail = e.message.toLowerCase();
      if (detail.contains('username')) {
        setState(() => _usernameError = 'This username is already taken.');
      } else if (detail.contains('email')) {
        setState(() => _emailError = 'An account with this email already exists.');
      } else {
        // Fallback: surface the server message as a username error
        setState(() => _usernameError = e.message);
      }
      debugPrint('⚠️ [SignUp] ApiException: ${e.statusCode} - ${e.message}');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect. Please check your internet connection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      debugPrint('⚠️ [SignUp] Unexpected error: $e');
    }
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────────

  Widget _buildFieldError(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 13),
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
    final accent = controller.accentColor;

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NeumorphicIconBadge(
                      icon: Icons.arrow_back_rounded,
                      iconSize: 20,
                      onTap: () => context.pop(),
                    ),
                    Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 28),

                // Welcome Header
                Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign up to start tracking and managing your expenses",
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // ── USERNAME ─────────────────────────────────────────────────
                Text(
                  "USERNAME",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                NeumorphicInputFieldWidget(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, color: textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          autocorrect: false,
                          onChanged: (_) {
                            if (_usernameError != null) setState(() => _usernameError = null);
                          },
                          decoration: InputDecoration(
                            hintText: "Choose a username",
                            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFieldError(_usernameError),
                const SizedBox(height: 16),

                // ── EMAIL ─────────────────────────────────────────────────────
                Text(
                  "EMAIL ADDRESS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                NeumorphicInputFieldWidget(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.email_rounded, color: textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          autocorrect: false,
                          onChanged: (_) {
                            if (_emailError != null) setState(() => _emailError = null);
                          },
                          decoration: InputDecoration(
                            hintText: "user@example.com",
                            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFieldError(_emailError),
                const SizedBox(height: 16),

                // ── PASSWORD ──────────────────────────────────────────────────
                Text(
                  "PASSWORD",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                NeumorphicInputFieldWidget(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                            if (_passwordError != null) setState(() => _passwordError = null);
                            // Also clear confirm error when password is edited
                            if (_confirmPasswordError != null) setState(() => _confirmPasswordError = null);
                          },
                          decoration: InputDecoration(
                            hintText: "••••••••••••",
                            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
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
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFieldError(_passwordError),
                const SizedBox(height: 16),

                // ── CONFIRM PASSWORD ──────────────────────────────────────────
                Text(
                  "CONFIRM PASSWORD",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                NeumorphicInputFieldWidget(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          onChanged: (_) {
                            if (_confirmPasswordError != null) setState(() => _confirmPasswordError = null);
                          },
                          decoration: InputDecoration(
                            hintText: "••••••••••••",
                            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        child: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFieldError(_confirmPasswordError),
                const SizedBox(height: 28),

                // Sign Up Button
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
                              "Sign Up",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Already have an account link
                Center(
                  child: GestureDetector(
                    onTap: () {
                      if (GoRouter.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go('/login');
                      }
                    },
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: textSecondary),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
