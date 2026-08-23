// File: lib/ui/features/auth/views/login_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../services/app_logger_service.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../data/repositories/chat_message_repository.dart';
import '../../../../services/category_service.dart';
import '../../../../services/isar_service.dart';
import '../../../../data/models/receipt_isar.dart';
import '../../../../data/models/chat_message_isar.dart';
import '../../../../domain/models/receipt.dart';
import 'package:isar/isar.dart';
import '../../../../cloud/api/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppLogger.info('UI', 'LoginScreen initialized');
    if (AuthService.instance.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard');
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isUuid(String id) {
    if (id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  Future<bool> _hasLocalGuestData() async {
    await ReceiptRepository.instance.init();
    await ConversationRepository.instance.init();
    await CategoryService.instance.init();

    List<Receipt> receipts = ReceiptRepository.instance.receipts;
    if (IsarService.isInitialized) {
      try {
        final models =
            await IsarService.isar.receiptIsarModels.where().findAll();
        receipts = models.map((m) => m.toDomain()).toList();
        AppLogger.info('UI',
            '_hasLocalGuestData direct Isar query found ${receipts.length} receipts');
      } catch (e) {
        AppLogger.error('UI', 'Error querying Isar in _hasLocalGuestData', e);
      }
    }

    final hasGuestReceipts = receipts.any((r) => !_isUuid(r.id));
    final hasGuestConversations = ConversationRepository.instance.conversations
        .any((c) => !_isUuid(c.id));

    bool hasGuestMessages = false;
    if (IsarService.isInitialized) {
      try {
        final msgs =
            await IsarService.isar.chatMessageIsarModels.where().findAll();
        hasGuestMessages = msgs.any((m) => !_isUuid(m.conversationId));
      } catch (e) {
        AppLogger.error(
            'UI', 'Error querying chat messages in _hasLocalGuestData', e);
      }
    }

    final hasCustomCategories =
        CategoryService.instance.customCategories.isNotEmpty;

    return hasGuestReceipts ||
        hasGuestConversations ||
        hasGuestMessages ||
        hasCustomCategories;
  }

  Future<void> _purgeLocalGuestData() async {
    AppLogger.info('UI',
        'Purging local guest data before logging in to existing account...');
    await ReceiptRepository.instance.clearAll();
    await ConversationRepository.instance.clearAll();
    await ChatMessageRepository.instance.clearAll();
    await CategoryService.instance.clearAll();
  }

  Future<bool> _showGuestOverrideWarningModal() async {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String inputText = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final canOverride = inputText.trim() == 'Override Data';
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Neumorphic(
                style: NeumorphicStyle(
                  depth: 0,
                  boxShape:
                      NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
                  color: NeumorphicTheme.baseColor(dialogContext),
                  border:
                      NeumorphicBorder(color: Colors.red.shade700, width: 2.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red.shade700, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Warning",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Cannot migrate local receipts, settings, and other data into an existing account. If you wish to save these data, please create a new account.",
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "To confirm data override, type 'Override Data' below (case-sensitive):",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: -3,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(10)),
                          color: NeumorphicTheme.baseColor(dialogContext),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          child: TextField(
                            onChanged: (val) {
                              setDialogState(() {
                                inputText = val;
                              });
                            },
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Override Data',
                              hintStyle: TextStyle(
                                  color: textSecondary.withValues(alpha: 0.5)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(
                              "Cancel",
                              style: TextStyle(color: textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              disabledBackgroundColor:
                                  Colors.red.shade900.withValues(alpha: 0.4),
                              disabledForegroundColor: Colors.white38,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: canOverride
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: Colors.red.shade900, width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onPressed: canOverride
                                ? () => Navigator.of(ctx).pop(true)
                                : null,
                            child: const Text(
                              "Override Data",
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return result ?? false;
  }

  Future<void> _onSignIn() async {
    AppLogger.info('UI', 'User tapped Sign In');
    final identifier = _usernameController.text.trim();
    final password = _passwordController.text;

    // Clear any previous error
    setState(() => _errorMessage = null);

    // Basic field validation — show same generic error to avoid enumeration
    if (identifier.isEmpty || password.isEmpty) {
      AppLogger.warning(
          'UI', 'Login validation failed: empty identifier or password');
      setState(() {
        _errorMessage =
            'Invalid username, email, or password. Please try again.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await BackendApiClient.instance.loginUser(
        username: identifier,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        AppLogger.warning('UI', 'Login failed: user response null');
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Invalid username, email, or password. Please try again.';
        });
        return;
      }

      // Check if local unsynced guest data exists BEFORE saving user session and linking device
      if (await _hasLocalGuestData()) {
        AppLogger.info('UI',
            'Local guest data detected. Prompting override warning modal...');
        final confirmed = await _showGuestOverrideWarningModal();
        if (!confirmed) {
          AppLogger.info('UI', 'User canceled override modal. Aborting login.');
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }
        await _purgeLocalGuestData();
      } else {
        // Clean slate: ensure local stores are cleared so no stale records duplicate with cloud data
        await _purgeLocalGuestData();
      }

      // Persist session and link hardware device AFTER modal confirmation / guest purge
      await AuthService.instance.saveSession(user, userToken: password);
      await AuthService.instance.linkCurrentDevice(user, userToken: password);

      // Perform initial cloud sync
      await CloudSyncService.instance.syncOnLogin();

      if (!mounted) return;
      setState(() => _isLoading = false);

      AppLogger.info('UI', 'User logged in successfully: ${user.username}');

      AppSnackBar.show(
        context,
        message: 'Welcome back, ${user.username}!',
      );

      // Navigate to dashboard, clearing the auth stack
      context.go('/dashboard');
    } on ApiException catch (e) {
      final msg = 'Invalid username, email, or password. Please try again.';
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
      if (mounted) {
        AppSnackBar.show(
          context,
          message: msg,
          isError: true,
        );
      }
      AppLogger.error(
          'UI', 'Login ApiException: ${e.statusCode} - ${e.message}', e);
    } catch (e) {
      const msg = 'Unable to connect. Please check your internet connection.';
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
      if (mounted) {
        AppSnackBar.show(
          context,
          message: msg,
          isError: true,
        );
      }
      AppLogger.error('UI', 'Login unexpected error: $e', e);
    }
  }

  void _onForgetPassword() {
    AppLogger.info('UI', 'User tapped Forget Password');
    context.push('/forgot-password');
  }

  void _onSignUp() {
    AppLogger.info('UI', 'User tapped Sign Up');
    context.push('/signup');
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
                // Top Navigation Back Pill
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        AppLogger.info('UI', 'User tapped Back on LoginScreen');
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
                const SizedBox(height: 28),

                // Welcome Header
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to your account to sync and manage your receipts on ${ApiConfig.appName}",
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // ── USERNAME OR EMAIL ─────────────────────────────────────────
                Text(
                  "USERNAME OR EMAIL",
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
                      Icon(Icons.person_rounded,
                          color: textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: "Enter your username or email",
                            hintStyle: TextStyle(
                                color: textSecondary.withValues(alpha: 0.6),
                                fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
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
                ),

                // Repositioned Forgot Password Link (Directly below Password)
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _onForgetPassword,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Inline Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 12),

                // ── Sign In Button ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: NeumorphicButtonWidget(
                    onPressed: _isLoading ? null : _onSignIn,
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
                              "Sign In",
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
                const SizedBox(height: 28),

                // ── Bottom Centered Sign Up Link ──────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _onSignUp,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: RichText(
                        text: TextSpan(
                          style:
                              TextStyle(fontSize: 13.5, color: textSecondary),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: "Sign Up",
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
}
