// File: lib/ui/features/settings/views/user_settings_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../cloud/services/device_identity_service.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/models/user_models.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../services/category_service.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../services/data_export_service.dart';
import '../../../../services/local_image_cache_service.dart';
import '../../../../services/app_logger_service.dart';
import '../../../../cloud/services/quota_service.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  UserRecordDto? _profile;
  Future<File?>? _avatarFuture;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _isManualSyncing = false;
  bool _isUploadingAvatar = false;
  bool _isExporting = false;
  final ImagePicker _imagePicker = ImagePicker();

  // ── EMAIL VERIFICATION STATE ─────────────────────────────────────────────
  /// Remaining cooldown seconds for OTP resend (persists across modal dismissals).
  int _verifyResendCooldownRemaining = 0;
  DateTime? _verifyCooldownStartedAt;

  @override
  void initState() {
    super.initState();
    AppLogger.info('UI', 'UserSettingsScreen initialized');
    _profile = AuthService.instance.cachedProfile;
    _isLoading = _profile == null;
    _avatarFuture =
        LocalImageCacheService.instance.getOrFetchAvatar(size: 'medium');
    QuotaService.instance.addListener(_onQuotaUpdated);
    LocalImageCacheService.instance.addListener(_onAvatarUpdated);
    _loadProfile();
    QuotaService.instance.refreshQuota();
  }

  @override
  void dispose() {
    QuotaService.instance.removeListener(_onQuotaUpdated);
    LocalImageCacheService.instance.removeListener(_onAvatarUpdated);
    super.dispose();
  }

  void _onQuotaUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAvatarUpdated() {
    if (mounted) {
      setState(() {
        _avatarFuture =
            LocalImageCacheService.instance.getOrFetchAvatar(size: 'medium');
      });
    }
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.instance.getOrFetchProfile();
    if (mounted && profile != null) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();

      // Client-side validation: 20MB ceiling
      if (bytes.length > 20 * 1024 * 1024) {
        if (mounted) {
          AppSnackBar.show(
            context,
            message:
                "Image size exceeds 20MB limit. Please select a smaller photo.",
            isError: true,
          );
        }
        return;
      }

      setState(() => _isUploadingAvatar = true);
      AppLogger.info('UI', 'Uploading new avatar (${bytes.length} bytes)...');

      final success = await AuthService.instance.updateAvatar(
        imageBytes: bytes,
        filename: pickedFile.name,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _avatarFuture = LocalImageCacheService.instance
                .getOrFetchAvatar(size: 'medium', forceRefresh: false);
            _profile = AuthService.instance.cachedProfile;
            _isUploadingAvatar = false;
          });
          AppSnackBar.show(context, message: "Avatar updated successfully!");
        } else {
          setState(() => _isUploadingAvatar = false);
          AppSnackBar.show(
            context,
            message: "Failed to upload avatar. Please try again.",
            isError: true,
          );
        }
      }
    } catch (e, st) {
      AppLogger.error('UI', 'Error picking or uploading avatar', e, st);
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Error selecting image: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _showAvatarPickerBottomSheet(BuildContext context, Color accent,
      Color textPrimary, Color textSecondary) async {
    AppLogger.info('UI', 'User opened Avatar Picker bottom sheet');
    await showModalBottomSheet(
      context: context,
      backgroundColor: NeumorphicTheme.baseColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Update Profile Photo",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Choose how you would like to select your avatar image (max 20MB).",
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadAvatar(ImageSource.camera);
                      },
                      child: Neumorphic(
                        style: NeumorphicStyle(
                          depth: 4,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(16)),
                          color: NeumorphicTheme.baseColor(context),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_rounded,
                                size: 32, color: accent),
                            const SizedBox(height: 8),
                            Text(
                              "Take Photo",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadAvatar(ImageSource.gallery);
                      },
                      child: Neumorphic(
                        style: NeumorphicStyle(
                          depth: 4,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(16)),
                          color: NeumorphicTheme.baseColor(context),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_rounded,
                                size: 32, color: accent),
                            const SizedBox(height: 8),
                            Text(
                              "Choose Gallery",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _copyToClipboard(String text, String label) {
    AppLogger.info('UI', 'User copied $label to clipboard: $text');
    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.show(
      context,
      message: "$label copied to clipboard!",
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _onManualSync() async {
    if (_isManualSyncing) return;
    setState(() => _isManualSyncing = true);
    AppLogger.info(
        'UI', 'User triggered manual cloud sync from UserSettingsScreen');

    try {
      await CloudSyncService.instance.syncOnLogin();
      await _loadProfile();
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Cloud sync complete! All records are up to date.",
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Sync failed: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  Future<void> _onExportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final result = await DataExportService.instance
          .exportToFile(format: ExportFormat.json);
      if (mounted) {
        if (result.success && result.filePath != null) {
          final path = result.filePath!;
          AppSnackBar.show(
            context,
            message: "Backup saved (${result.receiptsCount} receipts):\n$path",
          );

          if (!kIsWeb && Platform.isIOS) {
            try {
              await Share.shareXFiles([XFile(path)],
                  text: 'SancFund Database Backup');
            } catch (_) {}
          } else if (!kIsWeb && Platform.isAndroid) {
            try {
              await OpenFilex.open(path);
            } catch (_) {}
          }
        } else {
          AppSnackBar.show(
            context,
            message: "Export failed: ${result.errorMessage ?? 'Unknown error'}",
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Export failed: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ── EMAIL VERIFICATION BOTTOM SHEET ─────────────────────────────────────
  Future<void> _showEmailVerificationBottomSheet({
    required BuildContext context,
    required String email,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
  }) async {
    AppLogger.info('UI', 'User opened Email Verification modal');

    final controller = AppThemeController.instance;

    // Recalculate remaining cooldown from stored start time
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
      builder: (_) => _EmailVerificationSheet(
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
        onVerified: (updatedProfile) {
          if (mounted) {
            setState(() {
              _profile = updatedProfile;
            });
            AppSnackBar.show(
              context,
              message: '✓ Email verified successfully!',
            );
          }
        },
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showAddMobileBottomSheet(BuildContext context, Color accent,
      Color textPrimary, Color textSecondary) async {
    AppLogger.info('UI', 'User opened Add Mobile modal');
    final countryCodeController =
        TextEditingController(text: _profile?.countryCode ?? "+60");
    final mobileController =
        TextEditingController(text: _profile?.mobileNumber ?? "");
    bool isSaving = false;
    String? errorMsg;

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
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Mobile Number",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Enter your country code and mobile contact number.",
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Country Code Input
                      SizedBox(
                        width: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "CODE",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            NeumorphicInputFieldWidget(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              child: TextField(
                                controller: countryCodeController,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                style:
                                    TextStyle(color: textPrimary, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: "+60",
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Mobile Number Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "MOBILE NUMBER",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            NeumorphicInputFieldWidget(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              child: TextField(
                                controller: mobileController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(20),
                                ],
                                style:
                                    TextStyle(color: textPrimary, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: "123456789",
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    height: 48,
                    child: NeumorphicButtonWidget(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final cc = countryCodeController.text.trim();
                              final mn = mobileController.text.trim();
                              if (mn.isEmpty) {
                                AppLogger.warning('UI',
                                    'Mobile number save validation failed: empty mobile number');
                                setModalState(() =>
                                    errorMsg = "Please enter a mobile number.");
                                return;
                              }
                              AppLogger.info('UI', 'User saving mobile number');
                              setModalState(() {
                                isSaving = true;
                                errorMsg = null;
                              });

                              final success =
                                  await AuthService.instance.updateMobileNumber(
                                countryCode: cc.isEmpty ? "+60" : cc,
                                mobileNumber: mn,
                              );

                              if (success && context.mounted) {
                                AppLogger.info(
                                    'UI', 'Mobile number updated successfully');
                                Navigator.of(ctx).pop();
                                _loadProfile();
                                AppSnackBar.show(
                                  context,
                                  message: "Mobile number updated!",
                                );
                              } else {
                                AppLogger.warning('UI',
                                    'Mobile number update failed on backend');
                                setModalState(() {
                                  isSaving = false;
                                  errorMsg =
                                      "Failed to update mobile number. Please try again.";
                                });
                              }
                            },
                      child: Center(
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                "Save Mobile Number",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePasswordBottomSheet(
    BuildContext context,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
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
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.lock_reset_rounded,
                              color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Reset Account Password",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Enter your current password and choose a new secure password.",
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Current Password Field
                    Text(
                      "CURRENT PASSWORD",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    NeumorphicInputFieldWidget(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              color: textSecondary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: oldPasswordController,
                              obscureText: obscureOld,
                              style:
                                  TextStyle(color: textPrimary, fontSize: 14),
                              onChanged: (_) {
                                if (errorMsg != null) {
                                  setModalState(() => errorMsg = null);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: "Enter current password",
                                hintStyle: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.5),
                                    fontSize: 13),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setModalState(() => obscureOld = !obscureOld),
                            child: Icon(
                              obscureOld
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: textSecondary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // New Password Field
                    Text(
                      "NEW PASSWORD",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    NeumorphicInputFieldWidget(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.key_rounded,
                              color: textSecondary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: newPasswordController,
                              obscureText: obscureNew,
                              style:
                                  TextStyle(color: textPrimary, fontSize: 14),
                              onChanged: (_) => setModalState(() {
                                if (errorMsg != null) errorMsg = null;
                              }),
                              decoration: InputDecoration(
                                hintText: "Min 8 chars with symbols",
                                hintStyle: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.5),
                                    fontSize: 13),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setModalState(() => obscureNew = !obscureNew),
                            child: Icon(
                              obscureNew
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: textSecondary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Requirements Checklist
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildRequirementChip(
                            "8+ chars", hasMinLen, accent, textSecondary),
                        _buildRequirementChip(
                            "Uppercase", hasUpper, accent, textSecondary),
                        _buildRequirementChip(
                            "Lowercase", hasLower, accent, textSecondary),
                        _buildRequirementChip(
                            "Number", hasDigit, accent, textSecondary),
                        _buildRequirementChip(r"Special (!@#$)", hasSpecial,
                            accent, textSecondary),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Confirm New Password Field
                    Text(
                      "CONFIRM NEW PASSWORD",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    NeumorphicInputFieldWidget(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: (confirmPass.isNotEmpty &&
                                      confirmPass == newPass)
                                  ? Colors.green
                                  : textSecondary,
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: confirmPasswordController,
                              obscureText: obscureConfirm,
                              style:
                                  TextStyle(color: textPrimary, fontSize: 14),
                              onChanged: (_) => setModalState(() {
                                if (errorMsg != null) errorMsg = null;
                              }),
                              decoration: InputDecoration(
                                hintText: "Re-enter new password",
                                hintStyle: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.5),
                                    fontSize: 13),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(
                                () => obscureConfirm = !obscureConfirm),
                            child: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: textSecondary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: NeumorphicButtonWidget(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final oldP = oldPasswordController.text;
                                final newP = newPasswordController.text;
                                final confP = confirmPasswordController.text;

                                if (oldP.isEmpty) {
                                  setModalState(() => errorMsg =
                                      "Please enter your current password.");
                                  return;
                                }
                                if (!isStrong) {
                                  setModalState(() => errorMsg =
                                      "New password does not meet security requirements.");
                                  return;
                                }
                                if (newP == oldP) {
                                  setModalState(() => errorMsg =
                                      "New password cannot be the same as your old password.");
                                  return;
                                }
                                if (newP != confP) {
                                  setModalState(() =>
                                      errorMsg = "New passwords do not match.");
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  errorMsg = null;
                                });

                                try {
                                  await AuthService.instance.changePassword(
                                    oldPassword: oldP,
                                    newPassword: newP,
                                  );

                                  if (context.mounted) {
                                    Navigator.of(ctx).pop();
                                    AppSnackBar.show(
                                      context,
                                      message: "Password updated successfully!",
                                    );
                                  }
                                } catch (e) {
                                  String cleanError =
                                      "Failed to update password. Please check your current password.";
                                  if (e is ApiException) {
                                    cleanError = e.message;
                                  } else if (e.toString().contains(
                                      "Current password is incorrect")) {
                                    cleanError =
                                        "Current password is incorrect.";
                                  } else if (e
                                      .toString()
                                      .contains("cannot be the same")) {
                                    cleanError =
                                        "New password cannot be the same as your old password.";
                                  }
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMsg = cleanError;
                                  });
                                }
                              },
                        child: Center(
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  "Update Password",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
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

  Widget _buildRequirementChip(
    String label,
    bool isMet,
    Color accent,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMet
            ? Colors.green.withValues(alpha: 0.15)
            : textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isMet
              ? Colors.green.withValues(alpha: 0.6)
              : textSecondary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_rounded : Icons.circle_outlined,
            size: 11,
            color: isMet ? Colors.green : textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
              color: isMet ? Colors.green : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onLogout() async {
    AppLogger.info('UI', 'User tapped Log Out');
    if (_isLoggingOut) return;

    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Neumorphic(
            style: NeumorphicStyle(
              depth: 0,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
              color: NeumorphicTheme.baseColor(ctx),
              border: NeumorphicBorder(
                color: Colors.red.shade700.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Colors.red.shade600, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Log Out",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Are you sure you want to log out? Your cloud session will be closed and the app will return to guest mode.",
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: textSecondary,
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
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 11),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          "Log Out",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
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

    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);

    try {
      final user = _profile ?? AuthService.instance.cachedProfile;

      final exportData = await DataExportService.instance.exportGuestData();
      final hasLocalData = (exportData['receipts'] as List).isNotEmpty ||
          (exportData['conversations'] as List).isNotEmpty ||
          (exportData['chat_messages'] as List).isNotEmpty;

      // Best-effort pre-logout cloud sync
      if (hasLocalData && user != null) {
        try {
          await AuthService.instance.linkCurrentDevice(
            user,
            migrateData: exportData,
          );
        } catch (e) {
          AppLogger.warning(
              'UI', 'Pre-logout device sync failed (non-fatal): $e');
        }
      }

      // Best-effort device unlink and token rotation
      try {
        await AuthService.instance.linkCurrentDevice(null);
      } catch (e) {
        AppLogger.warning(
            'UI', 'Device unlink on logout failed (non-fatal): $e');
      }

      try {
        await DeviceIdentityService.instance
            .rotateDeviceToken(BackendApiClient.instance);
      } catch (e) {
        AppLogger.warning(
            'UI', 'Device token rotation on logout failed (non-fatal): $e');
      }

      // Guaranteed session clearance & Isar database purge
      await AuthService.instance.clearSession();

      if (!mounted) return;
      AppLogger.info('UI', 'User logged out successfully');
      AppSnackBar.show(
        context,
        message: "Logged out successfully.",
      );

      context.go('/dashboard');
    } catch (e) {
      // In any failure scenario, ensure local session is cleared and DB is purged
      await AuthService.instance.clearSession();
      if (!mounted) return;
      AppLogger.error('UI', 'Logout error: $e', e);
      AppSnackBar.show(
        context,
        message: "Logged out successfully.",
      );
      context.go('/dashboard');
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;

    final username =
        _profile?.username ?? AuthService.instance.currentUsername ?? 'User';
    final userId = _profile?.id ?? AuthService.instance.currentUserId ?? '';
    final email =
        _profile?.email ?? AuthService.instance.currentEmail ?? 'No email';
    final countryCode = _profile?.countryCode;
    final mobileNumber = _profile?.mobileNumber;
    final hasMobile = mobileNumber != null && mobileNumber.isNotEmpty;
    final deviceId = DeviceIdentityService.instance.deviceId;
    final createdAtRaw = _profile?.createdAt;
    String joinedDate = "Active Member";
    if (createdAtRaw != null && createdAtRaw.isNotEmpty) {
      try {
        final parsed = DateTime.parse(createdAtRaw);
        joinedDate = "Joined ${DateFormat.yMMMd().format(parsed)}";
      } catch (_) {}
    }

    final totalReceipts = ReceiptRepository.instance.receipts.length;
    final totalConversations =
        ConversationRepository.instance.conversations.length;
    final totalCategories = 6 + CategoryService.instance.customCategoryCount;

    // ── USER TIER RESOLUTION & STYLING ──────────────────────────────────
    final rawTier = _profile?.tier ?? QuotaService.instance.tier;
    final resolvedTier = rawTier.toUpperCase();
    final Color tierColor;
    if (resolvedTier == 'PREMIUM') {
      tierColor = Colors.amber.shade700;
    } else if (resolvedTier == 'DEV') {
      tierColor = Colors.deepPurpleAccent;
    } else {
      tierColor = accent;
    }

    // ── 7-DAY PASSWORD COOLDOWN CALCULATION ──────────────────────────────
    final activeProfile = _profile ?? AuthService.instance.cachedProfile;
    final lastChangedStr =
        activeProfile?.preferences['password_changed_at'] as String?;
    DateTime? lastChanged;
    if (lastChangedStr != null) {
      lastChanged = DateTime.tryParse(lastChangedStr);
    }
    int cooldownDaysRemaining = 0;
    bool isPasswordCooldownActive = false;
    if (lastChanged != null) {
      final difference = DateTime.now().toUtc().difference(lastChanged.toUtc());
      const cooldownDuration = Duration(days: 7);
      if (difference < cooldownDuration) {
        final remainingSeconds =
            cooldownDuration.inSeconds - difference.inSeconds;
        cooldownDaysRemaining = (remainingSeconds / 86400).ceil();
        if (cooldownDaysRemaining < 1) cooldownDaysRemaining = 1;
        isPasswordCooldownActive = true;
      }
    }
    final cooldownMessage =
        "Change allowed in $cooldownDaysRemaining day${cooldownDaysRemaining > 1 ? 's' : ''}";

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top Navigation Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NeumorphicIconBadge(
                      icon: Icons.arrow_back_rounded,
                      iconSize: 20,
                      onTap: () {
                        AppLogger.info(
                            'UI', 'User tapped Back on UserSettingsScreen');
                        context.pop();
                      },
                    ),
                    Text(
                      "Account & Profile",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    // Quick Sync Icon Badge
                    GestureDetector(
                      onTap: _isManualSyncing ? null : _onManualSync,
                      child: Neumorphic(
                        style: NeumorphicStyle(
                          depth: 3,
                          intensity: 0.85,
                          boxShape: const NeumorphicBoxShape.circle(),
                          color: controller.currentBaseColor,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(9),
                          child: _isManualSyncing
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accent,
                                  ),
                                )
                              : Icon(
                                  Icons.sync_rounded,
                                  size: 18,
                                  color: accent,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Dynamic Content
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. HERO PROFILE CARD ──────────────────────────────
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(20),
                        child: _isLoading
                            ? SizedBox(
                                height: 110,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: accent,
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  Row(
                                    children: [
                                      // Avatar Circle with Ring and '+' Badge
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          GestureDetector(
                                            onTap: _isUploadingAvatar
                                                ? null
                                                : () =>
                                                    _showAvatarPickerBottomSheet(
                                                      context,
                                                      accent,
                                                      textPrimary,
                                                      textSecondary,
                                                    ),
                                            child: Neumorphic(
                                              style: NeumorphicStyle(
                                                depth: 5,
                                                boxShape:
                                                    const NeumorphicBoxShape
                                                        .circle(),
                                                color: accent.withValues(
                                                    alpha: 0.15),
                                                border: NeumorphicBorder(
                                                  color: accent.withValues(
                                                      alpha: 0.4),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: SizedBox(
                                                width: 60,
                                                height: 60,
                                                child: _isUploadingAvatar
                                                    ? Center(
                                                        child: SizedBox(
                                                          width: 22,
                                                          height: 22,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            color: accent,
                                                          ),
                                                        ),
                                                      )
                                                    : _buildAvatarContent(
                                                        username, accent),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: -2,
                                            right: -2,
                                            child: GestureDetector(
                                              onTap: _isUploadingAvatar
                                                  ? null
                                                  : () =>
                                                      _showAvatarPickerBottomSheet(
                                                        context,
                                                        accent,
                                                        textPrimary,
                                                        textSecondary,
                                                      ),
                                              child: Neumorphic(
                                                style: NeumorphicStyle(
                                                  depth: 3,
                                                  boxShape:
                                                      const NeumorphicBoxShape
                                                          .circle(),
                                                  color:
                                                      NeumorphicTheme.baseColor(
                                                          context),
                                                  border: NeumorphicBorder(
                                                    color: accent.withValues(
                                                        alpha: 0.5),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: accent.withValues(
                                                        alpha: 0.2),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.add_rounded,
                                                      size: 15,
                                                      color: accent,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      // User Info & Badges
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Top Row: Badges aligned to top right
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                // Tier Badge (Free / Premium / Dev)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: tierColor.withValues(
                                                        alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                      color:
                                                          tierColor.withValues(
                                                              alpha: 0.4),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    resolvedTier,
                                                    style: TextStyle(
                                                      color: tierColor,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withValues(
                                                            alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .cloud_done_rounded,
                                                        color: Colors.green,
                                                        size: 11,
                                                      ),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        "Synced",
                                                        style: TextStyle(
                                                          color: Colors.green,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            // Username (Full Width)
                                            Text(
                                              username,
                                              style: TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              joinedDate,
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
                                  const SizedBox(height: 16),
                                  // User ID Monospace Row
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: controller.currentBaseColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: textSecondary.withValues(
                                            alpha: 0.12),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.fingerprint_rounded,
                                            size: 16, color: textSecondary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            userId.isNotEmpty
                                                ? "UID: $userId"
                                                : "Local Guest Account",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary.withValues(
                                                  alpha: 0.85),
                                              fontFamily: 'monospace',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (userId.isNotEmpty)
                                          GestureDetector(
                                            onTap: () => _copyToClipboard(
                                                userId, "User ID"),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 15,
                                              color: accent,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 14),

                      // ── 1.5 PLAN & USAGE ──────────────────────────────────
                      _buildSectionHeader("PLAN & USAGE", textSecondary),
                      const SizedBox(height: 8),
                      _buildDailyQuotaCard(
                        controller: controller,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accent: accent,
                        tierColor: tierColor,
                        tierName: resolvedTier,
                      ),
                      const SizedBox(height: 18),

                      // ── 2. DYNAMIC STATS OVERVIEW ──────────────────────────
                      _buildSectionHeader("OVERVIEW & ACTIVITY", textSecondary),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatCard(
                            icon: Icons.receipt_long_rounded,
                            value: "$totalReceipts",
                            label: "Receipts",
                            color: accent,
                            controller: controller,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(width: 10),
                          _buildStatCard(
                            icon: Icons.chat_bubble_outline_rounded,
                            value: "$totalConversations",
                            label: "AI Chats",
                            color: Colors.tealAccent.shade400,
                            controller: controller,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(width: 10),
                          _buildStatCard(
                            icon: Icons.category_rounded,
                            value: "$totalCategories",
                            label: "Categories",
                            color: Colors.amberAccent.shade400,
                            controller: controller,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── 3. CONTACT & CREDENTIALS ───────────────────────────
                      _buildSectionHeader("CONTACT & SECURITY", textSecondary),
                      const SizedBox(height: 8),
                      NeumorphicCardWidget(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Email Row
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
                                        Text(
                                          email,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Verified badge or Verify button
                                  if (_profile?.isEmailVerified == true)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_rounded,
                                          color: Colors.green,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Verified",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
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
                                          borderRadius:
                                              BorderRadius.circular(8),
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

                            // Mobile Number Row (Temporarily disabled - Coming Soon)
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
                                          : textSecondary.withValues(
                                              alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.phone_iphone_rounded,
                                      size: 18,
                                      color: hasMobile
                                          ? accent
                                          : textSecondary.withValues(
                                              alpha: 0.5),
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
                                        depth: -2.5,
                                        intensity: 0.8,
                                        color:
                                            NeumorphicTheme.baseColor(context),
                                        boxShape: NeumorphicBoxShape.roundRect(
                                            BorderRadius.circular(8)),
                                        border: NeumorphicBorder(
                                          color: textSecondary.withValues(
                                              alpha: 0.25),
                                          width: 1,
                                        ),
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
                                                alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildDivider(textSecondary),

                            // Reset Password Row
                            InkWell(
                              onTap: isPasswordCooldownActive
                                  ? null
                                  : () => _showChangePasswordBottomSheet(
                                        context,
                                        accent,
                                        textPrimary,
                                        textSecondary,
                                      ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isPasswordCooldownActive
                                            ? textSecondary.withValues(
                                                alpha: 0.08)
                                            : accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.lock_reset_rounded,
                                        size: 18,
                                        color: isPasswordCooldownActive
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
                                              color: isPasswordCooldownActive
                                                  ? textSecondary.withValues(
                                                      alpha: 0.5)
                                                  : textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isPasswordCooldownActive)
                                      Tooltip(
                                        message: cooldownMessage,
                                        triggerMode: TooltipTriggerMode.tap,
                                        child: Neumorphic(
                                          style: NeumorphicStyle(
                                            depth: -2.5,
                                            intensity: 0.8,
                                            color: NeumorphicTheme.baseColor(
                                                context),
                                            boxShape:
                                                NeumorphicBoxShape.roundRect(
                                                    BorderRadius.circular(8)),
                                            border: NeumorphicBorder(
                                              color: textSecondary.withValues(
                                                  alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.schedule_rounded,
                                                  size: 12,
                                                  color: textSecondary
                                                      .withValues(alpha: 0.6),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Reset",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: textSecondary
                                                        .withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  accent.withValues(alpha: 0.5),
                                              width: 1),
                                        ),
                                        child: Text(
                                          "Reset",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            _buildDivider(textSecondary),

                            // Security Encryption Row
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
                                    child: Icon(Icons.shield_outlined,
                                        size: 18, color: accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "AUTHENTICATION METHOD",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: textSecondary,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "PBKDF2 SHA-256 Cloud Token",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textPrimary,
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
                      const SizedBox(height: 20),

                      // ── 4. LINKED HARDWARE DEVICE ──────────────────────────
                      _buildSectionHeader(
                          "LINKED HARDWARE DEVICE", textSecondary),
                      const SizedBox(height: 8),
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.devices_rounded,
                                    size: 20, color: accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Physical Hardware Identity",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Authorized",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Device ID: $deviceId",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: textSecondary.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── 5. CLOUD & DATA ACTIONS ────────────────────────────
                      _buildSectionHeader("DATA MANAGEMENT", textSecondary),
                      const SizedBox(height: 8),
                      NeumorphicCardWidget(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Sync Now Action Row
                            InkWell(
                              onTap: _isManualSyncing ? null : _onManualSync,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(18)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.cloud_upload_outlined,
                                        color: accent, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Sync All Data Now",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Force push local receipts & pull updates",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _isManualSyncing ? "Syncing..." : "Sync",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _buildDivider(textSecondary),
                            // Quick Export Row
                            InkWell(
                              onTap: _onExportData,
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(18)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.file_download_outlined,
                                        color: accent, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Backup Receipts (JSON)",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Create offline archive of all records",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      "Export",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── 6. LEGAL & COMPLIANCE ─────────────────────────────
                      _buildSectionHeader("LEGAL & COMPLIANCE", textSecondary),
                      const SizedBox(height: 8),
                      NeumorphicCardWidget(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Privacy Policy
                            InkWell(
                              onTap: () => context.push('/legal/privacy'),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(18)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.security_rounded,
                                        color: accent, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Privacy Policy",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "GDPR, CCPA/CPRA & Zero AI Training",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        color: textSecondary, size: 14),
                                  ],
                                ),
                              ),
                            ),
                            _buildDivider(textSecondary),

                            // Terms of Service
                            InkWell(
                              onTap: () => context.push('/legal/terms'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.gavel_rounded,
                                        color: accent, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Terms of Service",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Acceptable use & governing law",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        color: textSecondary, size: 14),
                                  ],
                                ),
                              ),
                            ),
                            _buildDivider(textSecondary),

                            // Cookie Policy
                            InkWell(
                              onTap: () => context.push('/legal/cookies'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.cookie_outlined,
                                        color: accent, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Cookie & Storage Policy",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Secure tokens, cache & local database",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        color: textSecondary, size: 14),
                                  ],
                                ),
                              ),
                            ),
                            _buildDivider(textSecondary),

                            // Accessibility Statement
                            InkWell(
                              onTap: () => context.push('/legal/accessibility'),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(18)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.accessibility_new_rounded,
                                        color: accent, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Accessibility Statement",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "ADA Title III & WCAG 2.1 AA",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        color: textSecondary, size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── 7. DANGER ZONE / LOGOUT ────────────────────────────
                      _buildSectionHeader("SESSION ACTIONS", textSecondary),
                      const SizedBox(height: 8),
                      NeumorphicCardWidget(
                        color: Colors.red.withValues(alpha: 0.04),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.redAccent.shade200, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Cloud Session",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent.shade200,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Logging out will securely sync your data to the cloud and return this device to guest mode.",
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: NeumorphicButtonWidget(
                                color: Colors.red.shade700,
                                borderRadius: 12,
                                onPressed: _isLoggingOut ? null : _onLogout,
                                child: Center(
                                  child: _isLoggingOut
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.logout_rounded,
                                                color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              "Log Out",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildDailyQuotaCard({
    required AppThemeController controller,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color tierColor,
    required String tierName,
  }) {
    final quotaSvc = QuotaService.instance;
    final isDev = tierName.toUpperCase() == 'DEV';
    final scanUsed = quotaSvc.scanUsed;
    final scanLimit = quotaSvc.scanLimit;
    final isScanUnlimited = quotaSvc.isScanUnlimited || isDev;
    final scanProgress = isScanUnlimited
        ? 1.0
        : (scanUsed / (scanLimit > 0 ? scanLimit : 1)).clamp(0.0, 1.0);

    final chatUsed = quotaSvc.chatUsed;
    final chatLimit = quotaSvc.chatLimit;
    final isChatUnlimited = quotaSvc.isChatUnlimited || isDev;
    final chatProgress = isChatUnlimited
        ? 1.0
        : (chatUsed / (chatLimit > 0 ? chatLimit : 1)).clamp(0.0, 1.0);

    final scanLabel = isScanUnlimited
        ? "$scanUsed / Unlimited"
        : "$scanUsed / $scanLimit used";
    final chatUsedStr = chatUsed >= 1000
        ? "${(chatUsed / 1000).toStringAsFixed(chatUsed % 1000 == 0 ? 0 : 1)}k"
        : "$chatUsed";
    final chatLimitStr = isChatUnlimited
        ? "Unlimited"
        : (chatLimit >= 1000 ? "${chatLimit ~/ 1000}k" : "$chatLimit");
    final chatLabel = isChatUnlimited
        ? "$chatUsedStr / Unlimited"
        : "$chatUsedStr / $chatLimitStr used";

    final amberColor = Colors.amber.shade500;

    return NeumorphicCardWidget(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: [Tier Icon + (Tier Name & Countdown) & Subtext] and [Upgrade Button]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Deepened Indented Tier Icon
                    Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tierName == 'PREMIUM'
                            ? Icons.workspace_premium_rounded
                            : (tierName == 'DEV'
                                ? Icons.developer_mode_rounded
                                : Icons.bolt_rounded),
                        size: 18,
                        color: tierColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                tierName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Countdown pill component directly beside Tier Name
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: controller.currentBaseColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        textSecondary.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule_rounded,
                                        size: 11, color: textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      quotaSvc.liveResetCountdown,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Resets 00:00 UTC",
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (tierName == 'FREE') ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showPremiumUpgradeBottomSheet(
                    context,
                    controller,
                    accent,
                    textPrimary,
                    textSecondary,
                  ),
                  child: Neumorphic(
                    style: NeumorphicStyle(
                      depth: 3,
                      intensity: 0.9,
                      boxShape: NeumorphicBoxShape.roundRect(
                        BorderRadius.circular(10),
                      ),
                      color: controller.currentBaseColor,
                      border: NeumorphicBorder(
                        color: amberColor.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_double_arrow_up_rounded,
                          size: 15,
                          color: amberColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          "Upgrade",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: amberColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Scan Quota Metric (Deepened Indentation)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      "Receipt Scans",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  scanLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: quotaSvc.isScanQuotaExhausted
                        ? Colors.redAccent
                        : textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: isScanUnlimited ? 1.0 : scanProgress,
                minHeight: 6,
                backgroundColor: controller.isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  quotaSvc.isScanQuotaExhausted
                      ? Colors.redAccent
                      : (isScanUnlimited ? Colors.deepPurpleAccent : accent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Chat Token Quota Metric (Deepened Indentation)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 14, color: Colors.tealAccent.shade400),
                    const SizedBox(width: 6),
                    Text(
                      "AI Chat Tokens",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  chatLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: quotaSvc.isChatQuotaExhausted
                        ? Colors.redAccent
                        : textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: isChatUnlimited ? 1.0 : chatProgress,
                minHeight: 6,
                backgroundColor: controller.isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  quotaSvc.isChatQuotaExhausted
                      ? Colors.redAccent
                      : (isChatUnlimited
                          ? Colors.deepPurpleAccent
                          : Colors.tealAccent.shade400),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumUpgradeBottomSheet(
    BuildContext context,
    AppThemeController controller,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    AppLogger.info('UI', 'User opened Premium Upgrade bottom sheet');
    final amberColor = Colors.amber.shade500;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: NeumorphicTheme.baseColor(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Top Header Badge & Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: amberColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: amberColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: amberColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Upgrade to Premium",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: amberColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "TIER",
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: amberColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Supercharge your receipt workflow and unlock advanced AI.",
                            style:
                                TextStyle(fontSize: 12.5, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Benefits Container
                Container(
                  decoration: BoxDecoration(
                    color: controller.currentBaseColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: textSecondary.withValues(alpha: 0.12),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildPaywallBenefitRow(
                        icon: Icons.camera_alt_rounded,
                        iconColor: accent,
                        title: "50 Daily Receipt Scans",
                        description:
                            "5x higher daily scan allowance (50/day vs 10/day on Free) for high-volume receipt extraction.",
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const Divider(height: 24, thickness: 0.7),
                      _buildPaywallBenefitRow(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: Colors.tealAccent.shade400,
                        title: "50,000 AI Chat Tokens",
                        description:
                            "5x AI token capacity for deep financial querying, item breakdowns, and spending trends.",
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const Divider(height: 24, thickness: 0.7),
                      _buildPaywallBenefitRow(
                        icon: Icons.bolt_rounded,
                        iconColor: amberColor,
                        title: "Priority Vision OCR Processing",
                        description:
                            "High-priority server queue for instant receipt digitisation and category parsing.",
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const Divider(height: 24, thickness: 0.7),
                      _buildPaywallBenefitRow(
                        icon: Icons.file_download_outlined,
                        iconColor: Colors.blueAccent.shade400,
                        title: "Advanced Financial Exports",
                        description:
                            "Unlimited multi-format CSV and PDF exports with full receipt item breakdowns.",
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Pricing Card & Purchase CTA
                NeumorphicCardWidget(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PREMIUM SUBSCRIPTION",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: textSecondary,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "\$4.99",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                " / month",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          AppSnackBar.show(
                            context,
                            message:
                                "In-app purchases launching soon! Stay tuned.",
                          );
                        },
                        child: Neumorphic(
                          style: NeumorphicStyle(
                            depth: 4,
                            intensity: 0.9,
                            boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12),
                            ),
                            color: amberColor.withValues(alpha: 0.15),
                            border: NeumorphicBorder(
                              color: amberColor,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.keyboard_double_arrow_up_rounded,
                                size: 16,
                                color: amberColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Upgrade",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: amberColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "Cancel anytime. Terms of Service & Privacy Policy apply.",
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaywallBenefitRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11.5,
                  color: textSecondary.withValues(alpha: 0.85),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required AppThemeController controller,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Expanded(
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 3,
          intensity: 0.85,
          color: controller.currentBaseColor,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(String username, Color accent) {
    if (AuthService.instance.isLoggedIn) {
      final avatarPath = _profile?.avatarImagePath;
      if (avatarPath != null &&
          avatarPath.isNotEmpty &&
          File(avatarPath).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(avatarPath),
            fit: BoxFit.cover,
            width: 60,
            height: 60,
            errorBuilder: (_, __, ___) => _buildAvatarInitial(username, accent),
          ),
        );
      }

      return FutureBuilder<File?>(
        future: _avatarFuture ??=
            LocalImageCacheService.instance.getOrFetchAvatar(size: 'medium'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                ),
              ),
            );
          }

          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.existsSync()) {
            return ClipOval(
              child: Image.file(
                snapshot.data!,
                key: ValueKey(
                    'user_settings_avatar_${snapshot.data!.path}_${LocalImageCacheService.instance.avatarRevision}'),
                fit: BoxFit.cover,
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) =>
                    _buildAvatarInitial(username, accent),
              ),
            );
          }
          return _buildAvatarInitial(username, accent);
        },
      );
    }

    return _buildAvatarInitial(username, accent);
  }

  Widget _buildAvatarInitial(String username, Color accent) {
    return Center(
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : "U",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: accent,
        ),
      ),
    );
  }
}

// ── EMAIL VERIFICATION BOTTOM SHEET WIDGET ────────────────────────────────────

class _EmailVerificationSheet extends StatefulWidget {
  const _EmailVerificationSheet({
    required this.email,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.controller,
    required this.initialCooldownRemaining,
    required this.onCooldownStarted,
    required this.onVerified,
  });

  final String email;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final AppThemeController controller;
  final int initialCooldownRemaining;
  final void Function(DateTime startedAt) onCooldownStarted;
  final void Function(UserRecordDto updatedProfile) onVerified;

  @override
  State<_EmailVerificationSheet> createState() =>
      _EmailVerificationSheetState();
}

class _EmailVerificationSheetState extends State<_EmailVerificationSheet> {
  int _step = 1; // 1 = Confirm Email, 2 = Enter OTP

  bool _isLoading = false;
  String? _errorMessage;

  final _otpController = TextEditingController();
  int _cooldownRemaining = 0;

  @override
  void initState() {
    super.initState();
    _cooldownRemaining = widget.initialCooldownRemaining;
    if (_cooldownRemaining > 0) {
      _startCooldownTimer();
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_cooldownRemaining > 0) _cooldownRemaining--;
      });
      return _cooldownRemaining > 0;
    });
  }

  Future<void> _onSendCode() async {
    if (_isLoading || _cooldownRemaining > 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService.instance.initiateVerification(
        type: 'email',
        identifier: widget.email,
      );
      final now = DateTime.now();
      widget.onCooldownStarted(now);
      if (!mounted) return;
      setState(() {
        _cooldownRemaining = 60;
        _step = 2;
        _isLoading = false;
      });
      _startCooldownTimer();
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
        _cooldownRemaining = e.retryAfterSeconds;
        _step = 2;
      });
      _startCooldownTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _onVerifyCode() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6 || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final updatedProfile = await AuthService.instance.completeVerification(
        type: 'email',
        identifier: widget.email,
        otp: otp,
      );
      if (!mounted) return;
      widget.onVerified(updatedProfile);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.controller.currentBaseColor;
    final accent = widget.accent;
    final textPrimary = widget.textPrimary;
    final textSecondary = widget.textSecondary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 8,
          color: baseColor,
          boxShape: NeumorphicBoxShape.roundRect(
            const BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  _step == 1
                      ? 'Verify Email Address'
                      : 'Enter Verification Code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _step == 1
                      ? 'We\'ll send a 6-digit code to your email address.'
                      : 'Enter the 6-digit code sent to:',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
                if (_step == 2) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Step 1: Email confirmation + Send button
                if (_step == 1) ...[
                  Neumorphic(
                    style: NeumorphicStyle(
                      depth: -3,
                      color: baseColor,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(12)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 18, color: textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.email,
                              style:
                                  TextStyle(fontSize: 14, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCta(
                    label: 'Send Verification Code',
                    onTap: _onSendCode,
                    accent: accent,
                    baseColor: baseColor,
                    isLoading: _isLoading,
                  ),
                ],

                // Step 2: OTP input + Verify button
                if (_step == 2) ...[
                  Neumorphic(
                    style: NeumorphicStyle(
                      depth: -3,
                      color: baseColor,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(12)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText: '------',
                          hintStyle: TextStyle(
                            fontSize: 28,
                            letterSpacing: 8,
                            color: textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Resend cooldown or Resend link
                  Center(
                    child: _cooldownRemaining > 0
                        ? Text(
                            'Resend code in ${_cooldownRemaining}s',
                            style:
                                TextStyle(fontSize: 12, color: textSecondary),
                          )
                        : GestureDetector(
                            onTap: _isLoading ? null : _onSendCode,
                            child: Text(
                              'Resend Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  _buildCta(
                    label: 'Verify Code',
                    onTap: _otpController.text.trim().length == 6
                        ? _onVerifyCode
                        : null,
                    accent: accent,
                    baseColor: baseColor,
                    isLoading: _isLoading,
                  ),
                ],

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 16, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCta({
    required String label,
    required VoidCallback? onTap,
    required Color accent,
    required Color baseColor,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: onTap != null ? 4 : -2,
          color: onTap != null ? accent : baseColor,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: onTap != null
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
