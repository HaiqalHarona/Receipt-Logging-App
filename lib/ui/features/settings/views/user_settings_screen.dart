// File: lib/ui/features/settings/views/user_settings_screen.dart

import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../cloud/services/device_identity_service.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/models/user_models.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../data/repositories/chat_message_repository.dart';
import '../../../../services/data_export_service.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  UserRecordDto? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.instance.getOrFetchProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  void _copyUserIdToClipboard(String userId) {
    Clipboard.setData(ClipboardData(text: userId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("User ID copied to clipboard!"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showAddMobileBottomSheet(BuildContext context, Color accent, Color textPrimary, Color textSecondary) async {
    final countryCodeController = TextEditingController(text: _profile?.countryCode ?? "+60");
    final mobileController = TextEditingController(text: _profile?.mobileNumber ?? "");
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              child: TextField(
                                controller: countryCodeController,
                                style: TextStyle(color: textPrimary, fontSize: 14),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              child: TextField(
                                controller: mobileController,
                                keyboardType: TextInputType.phone,
                                style: TextStyle(color: textPrimary, fontSize: 14),
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
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
                                setModalState(() => errorMsg = "Please enter a mobile number.");
                                return;
                              }
                              setModalState(() {
                                isSaving = true;
                                errorMsg = null;
                              });

                              final success = await AuthService.instance.updateMobileNumber(
                                countryCode: cc.isEmpty ? "+60" : cc,
                                mobileNumber: mn,
                              );

                              if (success && context.mounted) {
                                Navigator.of(ctx).pop();
                                _loadProfile(); // refresh cached profile state
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Mobile number updated!"),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                setModalState(() {
                                  isSaving = false;
                                  errorMsg = "Failed to update mobile number. Please try again.";
                                });
                              }
                            },
                      child: Center(
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    try {
      final user = _profile ?? AuthService.instance.cachedProfile;
      final token = AuthService.instance.currentUserToken;

      // 1. Export local Isar records to verify sync status
      final exportData = await DataExportService.instance.exportGuestData();
      final hasLocalData = (exportData['receipts'] as List).isNotEmpty ||
          (exportData['conversations'] as List).isNotEmpty ||
          (exportData['chat_messages'] as List).isNotEmpty;

      // 2. Strict cloud upload verification: upload local data before unlinking
      if (hasLocalData && user != null && token != null) {
        await AuthService.instance.linkCurrentDevice(
          user,
          userToken: token,
          migrateData: exportData,
        );
      }

      // 3. Purge all local Isar DB collections once upload is confirmed
      await ReceiptRepository.instance.clearAll();
      await ConversationRepository.instance.clearAll();
      await ChatMessageRepository.instance.clearAll();

      // 4. Unlink hardware device from user account on backend
      await AuthService.instance.linkCurrentDevice(null);

      // 5. Rotate deviceToken for guest security while keeping persistent deviceId
      await DeviceIdentityService.instance.rotateDeviceToken(BackendApiClient.instance);

      // 6. Clear local user session credentials
      await AuthService.instance.clearSession();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Logged out successfully. Cloud data synced and local storage purged."),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout canceled: Cloud sync failed ($e). Data preserved locally."),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;

    final username = _profile?.username ?? AuthService.instance.currentUsername ?? 'User';
    final userId = _profile?.id ?? AuthService.instance.currentUserId ?? '';
    final email = _profile?.email ?? AuthService.instance.currentEmail ?? 'No email';
    final countryCode = _profile?.countryCode;
    final mobileNumber = _profile?.mobileNumber;
    final hasMobile = mobileNumber != null && mobileNumber.isNotEmpty;

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Scrollable Content
              Expanded(
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
                            "User Settings",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 40), // Spacer balancing back button
                        ],
                      ),
                      const SizedBox(height: 24),

                      // User Information Card (Top Card)
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(20),
                        child: _isLoading
                            ? SizedBox(
                                height: 120,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: accent,
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                            // Row 1: Username
                            Row(
                              children: [
                                Icon(Icons.account_circle_rounded, color: accent, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    username,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Row 2: User ID + Copy to Clipboard Button
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "User ID: $userId",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary.withValues(alpha: 0.8),
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _copyUserIdToClipboard(userId),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.copy_rounded,
                                      size: 15,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(height: 1, thickness: 0.5),
                            ),

                            // Row 3: Left (Email) & Right (Mobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column — Email
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "EMAIL",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Right Column — Mobile
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "MOBILE",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (hasMobile)
                                        Text(
                                          "${countryCode ?? '+60'} $mobileNumber",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      else
                                        GestureDetector(
                                          onTap: () => _showAddMobileBottomSheet(
                                            context,
                                            accent,
                                            textPrimary,
                                            textSecondary,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: accent, width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_rounded, size: 14, color: accent),
                                                const SizedBox(width: 2),
                                                Text(
                                                  "Add",
                                                  style: TextStyle(
                                                    fontSize: 12,
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Area — Row-Wide Logout Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: NeumorphicButtonWidget(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: 12,
                    onPressed: _onLogout,
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Log Out",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
    );
  }
}
