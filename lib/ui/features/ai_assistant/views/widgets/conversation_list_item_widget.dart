// File: lib/ui/features/ai_assistant/views/widgets/conversation_list_item_widget.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../../data/repositories/conversation_repository.dart';
import '../../../../../domain/models/conversation.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_snack_bar.dart';

enum _ConversationMenuAction { editTitle, copyId, copyJson, delete }

/// Neumorphic list item card for a conversation in the Conversations list.
///
/// Displays:
/// - Left: Leading chat icon badge
/// - Center: Title & formatted [updatedAt] timestamp
/// - Right: Vertical 3-dots overflow menu (Edit Title, Copy ID, Copy as JSON, Delete)
class ConversationListItemWidget extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onTap;

  const ConversationListItemWidget({
    super.key,
    required this.conversation,
    this.onTap,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final localDt = dt.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final hour = localDt.hour == 0
        ? 12
        : (localDt.hour > 12 ? localDt.hour - 12 : localDt.hour);
    final minute = localDt.minute.toString().padLeft(2, '0');
    final period = localDt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    if (now.year == localDt.year &&
        now.month == localDt.month &&
        now.day == localDt.day) {
      return 'Today · $timeStr';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == localDt.year &&
        yesterday.month == localDt.month &&
        yesterday.day == localDt.day) {
      return 'Yesterday · $timeStr';
    }

    final monthStr = months[localDt.month - 1];
    if (now.year == localDt.year) {
      return '$monthStr ${localDt.day} · $timeStr';
    }

    return '$monthStr ${localDt.day}, ${localDt.year} · $timeStr';
  }

  void _handleMenuAction(
      BuildContext context, _ConversationMenuAction action) {
    switch (action) {
      case _ConversationMenuAction.editTitle:
        _showEditTitleDialog(context);
        break;
      case _ConversationMenuAction.copyId:
        Clipboard.setData(ClipboardData(text: conversation.id));
        AppSnackBar.show(
          context,
          message: 'Conversation ID copied to clipboard.',
        );
        break;
      case _ConversationMenuAction.copyJson:
        final jsonMap = {
          'id': conversation.id,
          'title': conversation.title,
          'created_at': conversation.createdAt.toIso8601String(),
          'updated_at': conversation.updatedAt.toIso8601String(),
        };
        final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);
        Clipboard.setData(ClipboardData(text: jsonStr));
        AppSnackBar.show(
          context,
          message: 'Conversation JSON copied to clipboard.',
        );
        break;
      case _ConversationMenuAction.delete:
        _confirmDelete(context);
        break;
    }
  }

  void _showEditTitleDialog(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final baseColor = controller.currentBaseColor;
    final titleController = TextEditingController(text: conversation.title);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Neumorphic(
          style: NeumorphicStyle(
            depth: 4,
            intensity: 0.8,
            color: baseColor,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_outlined, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Edit Title',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Neumorphic(
                  style: NeumorphicStyle(
                    depth: -3,
                    intensity: 0.8,
                    color: baseColor,
                    boxShape: NeumorphicBoxShape.roundRect(
                        BorderRadius.circular(12)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: titleController,
                    autofocus: true,
                    maxLength: 50,
                    style: TextStyle(
                      fontSize: 14,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter conversation title...',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: NeumorphicButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: NeumorphicStyle(
                          depth: 3,
                          color: baseColor,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeumorphicButton(
                        onPressed: () async {
                          final newTitle = titleController.text.trim();
                          if (newTitle.isEmpty) return;
                          Navigator.of(ctx).pop();
                          await ConversationRepository.instance
                              .updateTitle(conversation.id, newTitle);
                          if (!context.mounted) return;
                          AppSnackBar.show(
                            context,
                            message: 'Conversation title updated.',
                          );
                        },
                        style: NeumorphicStyle(
                          depth: 3,
                          color: accent,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text(
                          'Save',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final baseColor = controller.currentBaseColor;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Neumorphic(
          style: NeumorphicStyle(
            depth: 4,
            intensity: 0.8,
            color: baseColor,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade400, size: 36),
                const SizedBox(height: 12),
                Text(
                  'Delete Conversation?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "${conversation.title}"? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: NeumorphicButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: NeumorphicStyle(
                          depth: 3,
                          color: baseColor,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeumorphicButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ConversationRepository.instance
                              .softDeleteConversation(conversation.id);
                          if (!context.mounted) return;
                          AppSnackBar.show(
                            context,
                            message: 'Conversation deleted.',
                            isError: true,
                          );
                        },
                        style: NeumorphicStyle(
                          depth: 3,
                          color: Colors.red.shade400,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text(
                          'Delete',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    final baseColor = controller.currentBaseColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 3,
          intensity: 0.8,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
          color: baseColor,
        ),
        child: SizedBox(
          height: 76,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Leading chat icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: accent,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Center Column: Title & formatted timestamp
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title.isNotEmpty
                            ? conversation.title
                            : 'New Conversation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(conversation.updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Right: 3-dots popup menu
                PopupMenuButton<_ConversationMenuAction>(
                  onSelected: (action) => _handleMenuAction(context, action),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  color: baseColor,
                  elevation: 6,
                  icon: Neumorphic(
                    style: NeumorphicStyle(
                      depth: 2,
                      intensity: 0.8,
                      boxShape: const NeumorphicBoxShape.circle(),
                      color: baseColor,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: textSecondary,
                      size: 18,
                    ),
                  ),
                  itemBuilder: (ctx) => [
                    PopupMenuItem<_ConversationMenuAction>(
                      value: _ConversationMenuAction.editTitle,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: accent),
                          const SizedBox(width: 10),
                          Text(
                            'Edit Title',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ConversationMenuAction>(
                      value: _ConversationMenuAction.copyId,
                      child: Row(
                        children: [
                          Icon(Icons.content_copy_rounded,
                              size: 16, color: accent),
                          const SizedBox(width: 10),
                          Text(
                            'Copy Conversation ID',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ConversationMenuAction>(
                      value: _ConversationMenuAction.copyJson,
                      child: Row(
                        children: [
                          Icon(Icons.code_rounded, size: 16, color: accent),
                          const SizedBox(width: 10),
                          Text(
                            'Copy as JSON',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ConversationMenuAction>(
                      value: _ConversationMenuAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 16, color: Colors.red.shade400),
                          const SizedBox(width: 10),
                          Text(
                            'Delete Conversation',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}
