// File: lib/ui/features/settings/views/user_settings_screen.dart

import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import '../../../../services/app_logger_service.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  UserRecordDto? _profile;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _isManualSyncing = false;

  @override
  void initState() {
    super.initState();
    AppLogger.info('UI', 'UserSettingsScreen initialized');
    _profile = AuthService.instance.cachedProfile;
    _isLoading = _profile == null;
    _loadProfile();
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
    try {
      final exportData = await DataExportService.instance.exportGuestData();
      final receiptsCount = (exportData['receipts'] as List).length;
      if (mounted) {
        AppSnackBar.show(
          context,
          message:
              "Export generated: $receiptsCount receipts ready for backup.",
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Export failed: $e",
          isError: true,
        );
      }
    }
  }

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
      final token = AuthService.instance.currentUserToken;

      final exportData = await DataExportService.instance.exportGuestData();
      final hasLocalData = (exportData['receipts'] as List).isNotEmpty ||
          (exportData['conversations'] as List).isNotEmpty ||
          (exportData['chat_messages'] as List).isNotEmpty;

      // Best-effort pre-logout cloud sync
      if (hasLocalData && user != null && token != null) {
        try {
          await AuthService.instance.linkCurrentDevice(
            user,
            userToken: token,
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
                                      // Avatar Circle with Ring
                                      Neumorphic(
                                        style: NeumorphicStyle(
                                          depth: 5,
                                          boxShape:
                                              const NeumorphicBoxShape.circle(),
                                          color: accent.withValues(alpha: 0.15),
                                          border: NeumorphicBorder(
                                            color:
                                                accent.withValues(alpha: 0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: SizedBox(
                                          width: 58,
                                          height: 58,
                                          child: Center(
                                            child: Text(
                                              username.isNotEmpty
                                                  ? username[0].toUpperCase()
                                                  : "U",
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: accent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // User Info & Badges
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    username,
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
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
                                            const SizedBox(height: 4),
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
                                  Icon(Icons.verified_user_rounded,
                                      color: Colors.green, size: 18),
                                ],
                              ),
                            ),
                            _buildDivider(textSecondary),

                            // Mobile Number Row
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
                                    child: Icon(Icons.phone_iphone_rounded,
                                        size: 18, color: accent),
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
                                  GestureDetector(
                                    onTap: () => _showAddMobileBottomSheet(
                                      context,
                                      accent,
                                      textPrimary,
                                      textSecondary,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color:
                                                accent.withValues(alpha: 0.5),
                                            width: 1),
                                      ),
                                      child: Text(
                                        hasMobile ? "Edit" : "+ Add",
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

                      // ── 6. DANGER ZONE / LOGOUT ────────────────────────────
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
}
