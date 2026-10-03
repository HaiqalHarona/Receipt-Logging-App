// File: lib/ui/features/settings/views/user_settings_screen.dart

import 'dart:async';
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
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/fading_edge_scroll_view.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../cloud/services/device_identity_service.dart';
import '../../../../cloud/api/api_config.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/models/user_models.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../services/category_service.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../services/data_export_service.dart';
import '../../../../services/local_image_cache_service.dart';
import '../../../../services/app_logger_service.dart';
import '../../../../services/sync_coordinator.dart';
import '../../../../cloud/services/quota_service.dart';
import '../../subscription/views/premium_paywall_sheet.dart';
import '../../subscription/widgets/downgrade_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../cloud/services/subscription_service.dart';

class UserSettingsScreen extends StatefulWidget {
  final bool highlightPlan;

  const UserSettingsScreen({
    super.key,
    this.highlightPlan = false,
  });

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen>
    with WidgetsBindingObserver {
  UserRecordDto? _profile;
  Future<File?>? _avatarFuture;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _isManualSyncing = false;
  bool _isUploadingAvatar = false;
  bool _isSimulatingExpiry = false;
  bool _highlightPlan = false;
  Timer? _highlightTimer;
  final GlobalKey _planSectionKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.info('UI', 'UserSettingsScreen initialized');
    _profile = AuthService.instance.cachedProfile;
    _isLoading = _profile == null;
    _avatarFuture =
        LocalImageCacheService.instance.getOrFetchAvatar(size: 'medium');
    QuotaService.instance.addListener(_onQuotaUpdated);
    LocalImageCacheService.instance.addListener(_onAvatarUpdated);
    SyncCoordinator.instance.addListener(_onSyncCoordinatorUpdated);
    _loadProfile();
    QuotaService.instance.refreshQuota();

    if (widget.highlightPlan) {
      _highlightPlan = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_planSectionKey.currentContext != null) {
          Scrollable.ensureVisible(
            _planSectionKey.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
        _highlightTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _highlightPlan = false);
        });
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _highlightTimer?.cancel();
    QuotaService.instance.removeListener(_onQuotaUpdated);
    LocalImageCacheService.instance.removeListener(_onAvatarUpdated);
    SyncCoordinator.instance.removeListener(_onSyncCoordinatorUpdated);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && mounted) {
      AppLogger.info(
          'UI', 'App resumed in UserSettingsScreen; checking subscription entitlements');
      await SubscriptionService.instance.checkAndSyncEntitlements();
      await _loadProfile();
      if (mounted) {
        QuotaService.instance.refreshQuota();
      }
    }
  }

  void _onSyncCoordinatorUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isOnline => SyncCoordinator.instance.isOnline;

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

  Future<void> _simulateTrialExpiry() async {
    if (_isSimulatingExpiry) return;
    setState(() => _isSimulatingExpiry = true);
    try {
      AppLogger.info('UI', 'Simulating 14-day trial expiry...');
      await BackendApiClient.instance.simulateTrialExpiry();

      // Reset local day15 popup flag for current user so popup is guaranteed to show
      final userId = AuthService.instance.currentUserId;
      if (userId != null && userId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('downgrade_day15_popup_shown_$userId');
      }

      // Refresh profile & quota
      await AuthService.instance.getOrFetchProfile(force: true);
      await QuotaService.instance.refreshQuota();
      await _loadProfile();

      if (mounted) {
        AppSnackBar.show(
          context,
          message: '14-Day trial expired! Downgraded to Free tier.',
        );
        // Trigger Day 15 downgrade dialog
        await DowngradePopupHelper.checkAndShow(context);
      }
    } catch (e) {
      AppLogger.error('UI', 'Failed to simulate trial expiry: $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Failed to simulate trial expiry: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSimulatingExpiry = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    if (!_isOnline) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Avatar upload requires an active internet connection.",
          isError: true,
        );
      }
      return;
    }
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
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
                .getOrFetchAvatar(size: 'medium', forceRefresh: true);
          });
          await _avatarFuture;
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          final updatedProfile =
              await AuthService.instance.getOrFetchProfile(force: true);
          if (mounted) {
            setState(() {
              _profile = updatedProfile ?? AuthService.instance.cachedProfile;
            });
            AppSnackBar.show(context, message: "Avatar updated successfully!");
          }
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
    if (!_isOnline) {
      AppSnackBar.show(
        context,
        message: "Avatar upload requires an active internet connection.",
        isError: true,
      );
      return;
    }
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
                    child: NeumorphicTactileButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickAndUploadAvatar(ImageSource.camera);
                      },
                      depth: 4.0,
                      pressedDepth: 0.0,
                      pressedScale: 0.96,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(16)),
                      color: NeumorphicTheme.baseColor(context),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: NeumorphicTactileButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickAndUploadAvatar(ImageSource.gallery);
                      },
                      depth: 4.0,
                      pressedDepth: 0.0,
                      pressedScale: 0.96,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(16)),
                      color: NeumorphicTheme.baseColor(context),
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
    if (!_isOnline) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Data sync requires an active internet connection.",
          isError: true,
        );
      }
      return;
    }
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

  void _showExportFormatBottomSheet(
    BuildContext context,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        bool isExporting = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: NeumorphicTheme.baseColor(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: textSecondary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 18),
                  Text(
                    "Export Local Database",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Choose an export format to save all receipts, AI chats, and categories. Zero cloud requests are made.",
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // JSON Option
                  InkWell(
                    onTap: isExporting
                        ? null
                        : () async {
                            setModalState(() => isExporting = true);
                            await _handleExport(ctx, ExportFormat.json);
                          },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: textSecondary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.data_object_rounded,
                              color: accent, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "JSON Format (.json)",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Structured complete backup, best for re-importing",
                                  style: TextStyle(
                                    fontSize: 12,
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
                  const SizedBox(height: 12),
                  // CSV Option
                  InkWell(
                    onTap: isExporting
                        ? null
                        : () async {
                            setModalState(() => isExporting = true);
                            await _handleExport(ctx, ExportFormat.csv);
                          },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: textSecondary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.table_chart_outlined,
                              color: accent, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CSV Spreadsheet (.csv)",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Standard table format, best for Excel & Google Sheets",
                                  style: TextStyle(
                                    fontSize: 12,
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
                  if (isExporting) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Exporting local database...",
                            style:
                                TextStyle(fontSize: 13, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleExport(
      BuildContext modalContext, ExportFormat format) async {
    try {
      final result =
          await DataExportService.instance.exportToFile(format: format);
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop();
      }

      if (!mounted) return;

      if (result.success && result.filePath != null) {
        final path = result.filePath!;
        AppSnackBar.show(
          context,
          message:
              "Database exported (${result.receiptsCount} receipts):\n$path",
        );

        // Share or open based on platform
        if (!kIsWeb && Platform.isIOS) {
          try {
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(path)],
                subject: 'SancFund Database Backup',
              ),
            );
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
    } catch (e) {
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop();
      }
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Export error: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _onLogout() async {
    AppLogger.info('UI', 'User tapped Log Out');
    if (_isLoggingOut) return;
    if (!_isOnline) {
      AppSnackBar.show(
        context,
        message:
            "Log out requires an active internet connection to safeguard your local data.",
        isError: true,
      );
      return;
    }

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
    if (!AuthService.instance.isLoggedIn) {
      return const SizedBox.shrink();
    }

    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;

    final username =
        _profile?.username ?? AuthService.instance.currentUsername ?? 'User';
    final userId = _profile?.id ?? AuthService.instance.currentUserId ?? '';
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
    final trialStartStr =
        activeProfile?.preferences['trial_start_at'] as String?;
    final trialStart =
        trialStartStr != null ? DateTime.tryParse(trialStartStr) : null;
    final trialEnd = trialStart?.add(const Duration(days: 14));
    final isTrialActive = (resolvedTier == 'PREMIUM' ||
            activeProfile?.preferences['is_in_trial'] == true) &&
        trialStart != null &&
        trialEnd != null &&
        DateTime.now().toUtc().isBefore(trialEnd.toUtc());

    return PopScope(
      canPop: GoRouter.maybeOf(context)?.canPop() ?? false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          AppLogger.info('UI', 'UserSettingsScreen PopScope handled back -> go /dashboard');
          context.go('/dashboard');
        }
      },
      child: AppGradientBackground(
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
                      NeumorphicCircularButton(
                        icon: Icons.arrow_back_rounded,
                        iconSize: 20,
                        onTap: () {
                          AppLogger.info(
                              'UI', 'User tapped Back on UserSettingsScreen');
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
                          }
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
                    // Quick Sync Icon Button (identical protrusion to back button)
                    NeumorphicCircularButton(
                      icon: !_isOnline
                          ? Icons.sync_disabled_rounded
                          : Icons.sync_rounded,
                      iconColor: !_isOnline
                          ? textSecondary.withValues(alpha: 0.4)
                          : accent,
                      iconSize: 20,
                      tooltip: !_isOnline
                          ? "Sync requires an internet connection"
                          : "Sync all data",
                      isLoading: _isManualSyncing,
                      onTap: (!_isOnline || _isManualSyncing)
                          ? null
                          : _onManualSync,
                    ),
                  ],
                ),
              ),

              // Scrollable Dynamic Content
              Expanded(
                child: FadingEdgeScrollView(
                  fadeHeightTop: 20,
                  fadeHeightBottom: 28,
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
                                      Tooltip(
                                        message: !_isOnline
                                            ? "Avatar upload requires an internet connection"
                                            : "Change avatar photo",
                                        triggerMode: TooltipTriggerMode.tap,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            NeumorphicTactileButton(
                                              onPressed: (!_isOnline ||
                                                      _isUploadingAvatar)
                                                  ? null
                                                  : () =>
                                                      _showAvatarPickerBottomSheet(
                                                        context,
                                                        accent,
                                                        textPrimary,
                                                        textSecondary,
                                                      ),
                                              depth: !_isOnline ? 1.0 : 5.0,
                                              pressedDepth: 0.0,
                                              pressedScale: 0.96,
                                              boxShape:
                                                  const NeumorphicBoxShape
                                                      .circle(),
                                                   padding: EdgeInsets.zero,
                                              color: !_isOnline
                                                  ? textSecondary
                                                      .withValues(
                                                          alpha: 0.08)
                                                  : accent.withValues(
                                                      alpha: 0.15),
                                              border: NeumorphicBorder(
                                                color: !_isOnline
                                                    ? textSecondary
                                                        .withValues(
                                                            alpha: 0.2)
                                                    : accent.withValues(
                                                        alpha: 0.4),
                                                width: 1.5,
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
                                            Positioned(
                                              bottom: -2,
                                              right: -2,
                                              child: NeumorphicTactileButton(
                                                onPressed: (!_isOnline ||
                                                        _isUploadingAvatar)
                                                    ? null
                                                    : () =>
                                                        _showAvatarPickerBottomSheet(
                                                          context,
                                                          accent,
                                                          textPrimary,
                                                          textSecondary,
                                                        ),
                                                depth: !_isOnline ? 0.0 : 3.0,
                                                pressedDepth: 0.0,
                                                pressedScale: 0.92,
                                                boxShape:
                                                    const NeumorphicBoxShape
                                                        .circle(),
                                                color: NeumorphicTheme
                                                    .baseColor(context),
                                                border: NeumorphicBorder(
                                                  color: !_isOnline
                                                      ? textSecondary
                                                          .withValues(
                                                              alpha: 0.3)
                                                      : accent.withValues(
                                                          alpha: 0.5),
                                                  width: 1.5,
                                                ),
                                                padding: EdgeInsets.zero,
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: !_isOnline
                                                        ? textSecondary
                                                            .withValues(
                                                                alpha: 0.1)
                                                        : accent.withValues(
                                                            alpha: 0.2),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      !_isOnline
                                                          ? Icons
                                                              .wifi_off_rounded
                                                          : Icons.add_rounded,
                                                      size: 14,
                                                      color: !_isOnline
                                                          ? textSecondary
                                                              .withValues(
                                                                  alpha: 0.5)
                                                          : accent,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
                      AnimatedContainer(
                        key: _planSectionKey,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _highlightPlan
                                ? Colors.amber.shade500
                                : Colors.transparent,
                            width: _highlightPlan ? 2.5 : 0.0,
                          ),
                          boxShadow: _highlightPlan
                              ? [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: _buildDailyQuotaCard(
                          controller: controller,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          accent: accent,
                          tierColor: tierColor,
                          tierName: resolvedTier,
                          isTrialActive: isTrialActive,
                          trialEnd: trialEnd,
                        ),
                      ),
                      if (ApiConfig.isDevelopment) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _isSimulatingExpiry ? null : _simulateTrialExpiry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: controller.currentBaseColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: textSecondary.withValues(alpha: 0.2),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 16, color: accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Simulate 14-Day Trial Expiration",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Fast-forwards to Day 15 and triggers downgrade flow & 50% discount offer.",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isSimulatingExpiry)
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accent,
                                    ),
                                  )
                                else
                                  Icon(Icons.play_arrow_rounded,
                                      size: 18, color: accent),
                              ],
                            ),
                          ),
                        ),
                      ],
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

                      // ── 3. CONTACT & SECURITY ──────────────────────────────
                      _buildSectionHeader("CONTACT & SECURITY", textSecondary),
                      const SizedBox(height: 8),
                      NeumorphicCardWidget(
                        padding: EdgeInsets.zero,
                        child: NeumorphicPressableRow(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await context.push('/user-settings/contact-security');
                            if (mounted) {
                              _loadProfile();
                            }
                          },
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
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "View & Edit",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Change contact, configure security, and more",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: textSecondary,
                              ),
                            ],
                          ),
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
                            Tooltip(
                              message: !_isOnline
                                  ? "Sync requires an internet connection"
                                  : "Force push local receipts & pull updates",
                              triggerMode: TooltipTriggerMode.tap,
                              child: NeumorphicPressableRow(
                                onTap: (!_isOnline || _isManualSyncing)
                                    ? null
                                    : _onManualSync,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        !_isOnline
                                            ? Icons.cloud_off_outlined
                                            : Icons.cloud_upload_outlined,
                                        color: !_isOnline
                                            ? textSecondary.withValues(
                                                alpha: 0.4)
                                            : accent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
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
                                              color: !_isOnline
                                                  ? textSecondary.withValues(
                                                      alpha: 0.6)
                                                  : textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            !_isOnline
                                                ? "Connect to internet to synchronize data"
                                                : "Force push local receipts & pull updates",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      !_isOnline
                                          ? "Offline"
                                          : (_isManualSyncing
                                              ? "Syncing..."
                                              : "Sync"),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: !_isOnline
                                            ? textSecondary.withValues(
                                                alpha: 0.4)
                                            : accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _buildDivider(textSecondary),
                            // Quick Export Row
                            NeumorphicPressableRow(
                              onTap: () => _showExportFormatBottomSheet(
                                context,
                                accent,
                                textPrimary,
                                textSecondary,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(18)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.file_download_outlined,
                                      color: accent,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Export Database (JSON/CSV)",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Save receipts & chat backup to device",
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── 6. LEGAL & COMPLIANCE ─────────────────────────────
                      _buildSectionHeader("LEGAL & COMPLIANCE", textSecondary),
                      const SizedBox(height: 8),
                      NeumorphicCardWidget(
                        padding: EdgeInsets.zero,
                        child: NeumorphicPressableRow(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/settings/policies-tour'),
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
                                child: Icon(Icons.policy_outlined,
                                    size: 18, color: accent),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "View Policies & Tour",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Read our legal documents or play the app's walkthrough",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: textSecondary,
                              ),
                            ],
                          ),
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
                            if (!_isOnline)
                              Tooltip(
                                message:
                                    "Log out requires an internet connection to safeguard your local data",
                                triggerMode: TooltipTriggerMode.tap,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: NeumorphicButtonWidget(
                                    color: Colors.grey.shade700,
                                    borderRadius: 12,
                                    onPressed: null,
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.wifi_off_rounded,
                                              color: Colors.white
                                                  .withValues(alpha: 0.6),
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Log Out",
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.6),
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
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
                                                  color: Colors.white,
                                                  size: 18),
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
            ),
          ],
        ),
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
    bool isTrialActive = false,
    DateTime? trialEnd,
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

    final resetAtUtc = quotaSvc.status?.resetAt;
    final effectiveResetUtc = resetAtUtc ??
        () {
          final now = DateTime.now().toUtc();
          return DateTime.utc(now.year, now.month, now.day + 1);
        }();
    final localResetTimeStr =
        DateFormat('HH:mm').format(effectiveResetUtc.toLocal());

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
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
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
                        size: 28,
                        color: tierColor,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tierName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Countdown pill component directly below Tier Name with local reset tooltip
                          Tooltip(
                            message: "Quota resets at $localResetTimeStr",
                            triggerMode: TooltipTriggerMode.tap,
                            child: Container(
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (tierName == 'FREE') ...[
                const SizedBox(width: 8),
                NeumorphicTactileButton(
                  onPressed: () => _showPremiumUpgradeBottomSheet(
                    context,
                    controller,
                    accent,
                    textPrimary,
                    textSecondary,
                  ),
                  depth: controller.neuDepth,
                  pressedDepth: 0.0,
                  pressedScale: 0.96,
                  boxShape: NeumorphicBoxShape.roundRect(
                    BorderRadius.circular(10),
                  ),
                  color: controller.currentBaseColor,
                  border: NeumorphicBorder(
                    color: amberColor.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Text(
                    "Upgrade",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: amberColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ] else if (tierName == 'PREMIUM' && !isTrialActive) ...[
                const SizedBox(width: 8),
                NeumorphicTactileButton(
                  onPressed: () => _onManageTap(context),
                  depth: controller.neuDepth,
                  pressedDepth: 0.0,
                  pressedScale: 0.96,
                  boxShape: NeumorphicBoxShape.roundRect(
                    BorderRadius.circular(10),
                  ),
                  color: controller.currentBaseColor,
                  border: NeumorphicBorder(
                    color: textSecondary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.settings_rounded,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        "Manage",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (isTrialActive && trialEnd != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "14-Day Trial Active · Ends on ${DateFormat.yMMMd().format(trialEnd)}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  Future<void> _showPremiumUpgradeBottomSheet(
    BuildContext context,
    AppThemeController controller,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) async {
    AppLogger.info('UI', 'User opened Premium Upgrade paywall sheet');
    final upgraded = await showPremiumPaywallSheet(context);
    if (upgraded == true && mounted) {
      await AuthService.instance.getOrFetchProfile(force: true);
      await _loadProfile();
    }
  }

  Future<void> _onManageTap(BuildContext context) async {
    AppLogger.info('UI', 'User tapped Manage subscription');
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ManageSubscriptionSheet(),
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
          depth: controller.neuDepth,
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

/// Bottom sheet shown before launching Play Store subscription management.
/// Informs user that cancellation takes effect at cycle end, and plan changes defer.
class _ManageSubscriptionSheet extends StatelessWidget {
  const _ManageSubscriptionSheet();

  static const _playStoreUrl =
      'https://play.google.com/store/account/subscriptions';

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: NeumorphicTheme.baseColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.workspace_premium_rounded,
                  color: accent, size: 28),
            ),
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            "Manage Your Subscription",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Info bullets
          _ManageSubscriptionInfoRow(
            icon: Icons.cancel_outlined,
            iconColor: Colors.redAccent,
            text:
                "Cancel anytime — your current plan continues until the end of your billing period.",
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _ManageSubscriptionInfoRow(
            icon: Icons.swap_vert_rounded,
            iconColor: Colors.tealAccent.shade700,
            text:
                "Switch plans — the new plan activates automatically when your current period ends.",
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _ManageSubscriptionInfoRow(
            icon: Icons.store_rounded,
            iconColor: accent,
            text:
                "All billing is managed securely. The app updates your plan status automatically.",
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 22),

          // Action CTA
          SizedBox(
            height: 50,
            child: NeumorphicButtonWidget(
              onPressed: () async {
                Navigator.of(context).pop();
                final uri = Uri.parse(_playStoreUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    AppSnackBar.show(
                      context,
                      message:
                          'Could not open Google Play. Please manage your subscription directly in the Play Store app.',
                      isError: true,
                    );
                  }
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_new_rounded,
                      color: Colors.white, size: 17),
                  SizedBox(width: 8),
                  Text(
                    "Manage on Google Play",
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
          const SizedBox(height: 10),

          // Dismiss Button
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Dismiss",
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageSubscriptionInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textSecondary;

  const _ManageSubscriptionInfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style:
                TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
          ),
        ),
      ],
    );
  }
}
