// File: lib/ui/features/ai_assistant/views/chat_detail_screen.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../cloud/api/api_config.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/models/receipt_models.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../data/repositories/chat_message_repository.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/chat_message.dart';
import '../../../../domain/models/conversation.dart';
import '../../../../services/app_logger_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';

enum _ChatMenuAction { editTitle, copyId, copyJson, delete }

/// WhatsApp-style Chat Detail Screen for AI Assistant conversations in Guest & User mode.
///
/// Features:
/// - Header: Back button, Title ("Untitled" for new chats), formatted timestamp, and 3-dots overflow menu (Edit Title, Copy ID, Copy JSON, Delete).
/// - Chat Window: Real-time message thread rendering user and assistant bubbles with local timestamps.
/// - Optimistic pending message bubble & typing indicator while waiting for the AI response.
/// - Delayed Isar DB persistence: Creates Conversation & saves messages simultaneously only after 200 OK.
/// - Bottom Input Bar: Neumorphic pill input with attachment paperclip and circular send button.
class ChatDetailScreen extends StatefulWidget {
  final Conversation? conversation;

  const ChatDetailScreen({
    super.key,
    this.conversation,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Conversation? _conversation;
  String? _customTitle;
  List<ChatMessage> _messages = [];
  bool _isLoadingHistory = false;

  // In-flight generation state
  bool _isGenerating = false;
  String? _pendingUserPrompt;
  DateTime? _pendingUserTime;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    AppLogger.info('UI',
        'ChatDetailScreen opened: ${_conversation?.id ?? "new_empty_chat"}');
    if (_conversation != null) {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (_conversation == null) return;
    setState(() => _isLoadingHistory = true);
    try {
      final history =
          await ChatMessageRepository.instance.fetchHistory(_conversation!.id);
      if (mounted) {
        setState(() {
          _messages = history;
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      AppLogger.error('UI', 'Failed to load chat history: $e', e);
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _formatHeaderTimestamp(DateTime dt) {
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

  /// Formats message timestamps with local time only (e.g. "10:14 AM").
  String _formatMessageTime(DateTime dt) {
    final localDt = dt.toLocal();
    final hour = localDt.hour == 0
        ? 12
        : (localDt.hour > 12 ? localDt.hour - 12 : localDt.hour);
    final minute = localDt.minute.toString().padLeft(2, '0');
    final period = localDt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _handleMenuAction(_ChatMenuAction action) {
    final conv = _conversation;
    switch (action) {
      case _ChatMenuAction.editTitle:
        _showEditTitleDialog();
        break;
      case _ChatMenuAction.copyId:
        final idToCopy = conv?.id ?? 'unsaved';
        Clipboard.setData(ClipboardData(text: idToCopy));
        AppSnackBar.show(
          context,
          message: 'Conversation ID copied to clipboard.',
        );
        break;
      case _ChatMenuAction.copyJson:
        final now = DateTime.now();
        final jsonMap = {
          'id': conv?.id ?? 'unsaved',
          'title': conv?.title.isNotEmpty == true
              ? conv!.title
              : (_customTitle ?? 'Untitled'),
          'created_at': (conv?.createdAt ?? now).toIso8601String(),
          'updated_at': (conv?.updatedAt ?? now).toIso8601String(),
          'messages': _messages
              .map((m) => {
                    'id': m.id,
                    'sender': m.sender,
                    'content': m.content,
                    'created_at': m.createdAt.toIso8601String(),
                  })
              .toList(),
        };
        final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);
        Clipboard.setData(ClipboardData(text: jsonStr));
        AppSnackBar.show(
          context,
          message: 'Conversation JSON copied to clipboard.',
        );
        break;
      case _ChatMenuAction.delete:
        _confirmDelete();
        break;
    }
  }

  void _showEditTitleDialog() {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final baseColor = controller.currentBaseColor;
    final currentTitle = _conversation?.title.isNotEmpty == true
        ? _conversation!.title
        : (_customTitle ?? 'New Conversation');
    final titleController = TextEditingController(text: currentTitle);

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
                    boxShape:
                        NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                          if (_conversation != null) {
                            await ConversationRepository.instance
                                .updateTitle(_conversation!.id, newTitle);
                            if (mounted) {
                              setState(() {
                                _conversation =
                                    _conversation!.copyWith(title: newTitle);
                              });
                            }
                          } else {
                            if (mounted) {
                              setState(() {
                                _customTitle = newTitle;
                              });
                            }
                          }
                          if (!mounted) return;
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

  void _confirmDelete() {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final baseColor = controller.currentBaseColor;
    final title = _conversation?.title ?? 'this conversation';

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
                  'Are you sure you want to delete "$title"? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: textSecondary, height: 1.4),
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
                          if (_conversation != null) {
                            await ConversationRepository.instance
                                .softDeleteConversation(_conversation!.id);
                            await ChatMessageRepository.instance
                                .deleteHistoryForConversation(
                                    _conversation!.id);
                          }
                          if (!mounted) return;
                          AppSnackBar.show(
                            context,
                            message: 'Conversation deleted.',
                            isError: true,
                          );
                          context.pop();
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

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    _messageController.clear();
    final now = DateTime.now();

    // 1. Optimistic UI state
    setState(() {
      _isGenerating = true;
      _pendingUserPrompt = text;
      _pendingUserTime = now;
    });
    _scrollToBottom();

    // 2. Prepare payload:
    // In User Mode: Pure Server RAG (server queries Supabase receipts & history directly)
    // In Guest Mode: Client-supplied local Isar history (max 50) and receipts (max 100)
    final isUser = AuthService.instance.isLoggedIn;
    final reqType = isUser ? 'user' : 'guest';

    List<Map<String, dynamic>>? convHistory;
    List<Map<String, dynamic>>? receiptsPayload;

    if (!isUser) {
      final last50Messages = _messages.length > 50
          ? _messages.sublist(_messages.length - 50)
          : _messages;
      convHistory = last50Messages
          .map((m) => {
                'role': m.sender,
                'content': m.content,
              })
          .toList();

      final allReceipts = ReceiptRepository.instance.receipts;
      final last100Receipts =
          allReceipts.length > 100 ? allReceipts.sublist(0, 100) : allReceipts;
      receiptsPayload = last100Receipts
          .map((r) => ReceiptDto.fromDomain(r).toJson())
          .toList();
    }

    try {
      AppLogger.info('UI',
          'Dispatching chat query: "$text" (mode: $reqType, conv: ${_conversation?.id ?? "new"})');

      final response = await BackendApiClient.instance.sendChatQuery(
        message: text,
        requestType: reqType,
        conversationId: isUser ? _conversation?.id : null,
        conversationHistory: convHistory,
        receipts: receiptsPayload,
        deviceName: isUser ? null : ApiConfig.deviceId,
        deviceToken: isUser ? null : ApiConfig.deviceToken,
        username: isUser ? AuthService.instance.currentUsername : null,
        userToken: isUser ? AuthService.instance.currentUserToken : null,
      );

      // 5. On successful 200 OK response:
      // If first turn of a new conversation, create conversation in Isar DB:
      if (_conversation == null) {
        final newConv =
            await ConversationRepository.instance.createConversation(
          id: response.conversationId.isNotEmpty
              ? response.conversationId
              : null,
          title: _customTitle?.isNotEmpty == true
              ? _customTitle!
              : 'New Conversation',
        );
        _conversation = newConv;
        AppLogger.info('UI',
            'Created initial conversation in Isar DB: ${_conversation!.id}');
      }

      // Simultaneously commit user message and assistant message to Isar DB:
      final userMsg = await ChatMessageRepository.instance.addMessage(
        conversationId: _conversation!.id,
        sender: 'user',
        content: text,
        id: response.userMessage.id,
      );

      final aiMsg = await ChatMessageRepository.instance.addMessage(
        conversationId: _conversation!.id,
        sender: 'assistant',
        content: response.assistantMessage.content,
        id: response.assistantMessage.id,
      );

      AppLogger.info('UI',
          'Saved user & AI messages to Isar DB for conv: ${_conversation!.id}');

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _pendingUserPrompt = null;
          _pendingUserTime = null;
          _messages = [..._messages, userMsg, aiMsg];
        });
        _scrollToBottom();
      }
    } catch (e, stackTrace) {
      AppLogger.error('UI', 'Failed to send chat query: $e', e, stackTrace);
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _pendingUserPrompt = null;
          _pendingUserTime = null;
          _messageController.text = text; // Keep text in input for re-trying
        });
        final errorMessage = e is ArgumentError
            ? e.message.toString()
            : 'Failed to get response. Please try again.';
        AppSnackBar.show(
          context,
          message: errorMessage,
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final baseColor = controller.currentBaseColor;

        final displayTitle = _conversation?.title.isNotEmpty == true
            ? _conversation!.title
            : (_customTitle?.isNotEmpty == true ? _customTitle! : 'Untitled');
        final displayTimestamp =
            _formatHeaderTimestamp(_conversation?.updatedAt ?? DateTime.now());

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Column(
                children: [
                  // ── Custom Neumorphic Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        // Back Button
                        NeumorphicButton(
                          onPressed: () => context.pop(),
                          style: NeumorphicStyle(
                            depth: 3,
                            boxShape: const NeumorphicBoxShape.circle(),
                            color: baseColor,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Updated At Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayTitle,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayTimestamp,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // 3-Dots Overflow Menu
                        PopupMenuButton<_ChatMenuAction>(
                          onSelected: _handleMenuAction,
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
                            PopupMenuItem<_ChatMenuAction>(
                              value: _ChatMenuAction.editTitle,
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 16, color: accent),
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
                            PopupMenuItem<_ChatMenuAction>(
                              value: _ChatMenuAction.copyId,
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
                            PopupMenuItem<_ChatMenuAction>(
                              value: _ChatMenuAction.copyJson,
                              child: Row(
                                children: [
                                  Icon(Icons.code_rounded,
                                      size: 16, color: accent),
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
                            PopupMenuItem<_ChatMenuAction>(
                              value: _ChatMenuAction.delete,
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

                  // ── Chat Window (Canvas) ──
                  Expanded(
                    child: _isLoadingHistory
                        ? Center(
                            child: CircularProgressIndicator(
                              color: accent,
                              strokeWidth: 2.5,
                            ),
                          )
                        : _buildMessageList(
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            accent: accent,
                            baseColor: baseColor,
                          ),
                  ),

                  // ── Bottom Message Input Bar (WhatsApp-style) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: Row(
                      children: [
                        // Neumorphic Input Pill
                        Expanded(
                          child: Neumorphic(
                            style: NeumorphicStyle(
                              depth: -3,
                              intensity: 0.8,
                              color: baseColor,
                              boxShape: NeumorphicBoxShape.roundRect(
                                  BorderRadius.circular(24)),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            child: Row(
                              children: [
                                // Paperclip Attachment Icon
                                Icon(
                                  Icons.attach_file_rounded,
                                  color: textSecondary.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),

                                // Text Input Field
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    enabled: !_isGenerating,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _isGenerating
                                          ? "AI is responding..."
                                          : "Ask about your spending...",
                                      hintStyle: TextStyle(
                                        fontSize: 13.5,
                                        color: textSecondary.withValues(
                                            alpha: 0.6),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 10),
                                    ),
                                    onSubmitted: (_) => _handleSendMessage(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Circular Send Button
                        NeumorphicButton(
                          onPressed: _isGenerating ? null : _handleSendMessage,
                          style: NeumorphicStyle(
                            depth: _isGenerating ? -2 : 3,
                            intensity: 0.85,
                            color: _isGenerating
                                ? baseColor.withValues(alpha: 0.6)
                                : accent,
                            boxShape: const NeumorphicBoxShape.circle(),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.send_rounded,
                            color: _isGenerating
                                ? textSecondary.withValues(alpha: 0.5)
                                : Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageList({
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color baseColor,
  }) {
    final hasMessages = _messages.isNotEmpty || _pendingUserPrompt != null;

    if (!hasMessages) {
      // Empty chat initial state with greeting
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Center Date Chip
          Center(
            child: Neumorphic(
              style: NeumorphicStyle(
                depth: -2,
                intensity: 0.7,
                color: baseColor,
                boxShape:
                    NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                "Today",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // AI Assistant Welcome Greeting Bubble
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: Neumorphic(
                style: NeumorphicStyle(
                  depth: 3,
                  intensity: 0.85,
                  color: baseColor,
                  boxShape:
                      NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5, right: 8),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: MarkdownBody(
                        data:
                            "👋 Hi there! I'm your AI financial assistant. Ask me anything about your spending, merchant details, or budgets.",
                        selectable: true,
                        styleSheet: _buildMarkdownStyleSheet(
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          accent: accent,
                          baseColor: baseColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _messages.length +
          (_pendingUserPrompt != null ? 2 : 0), // pending user + typing bubble
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          final msg = _messages[index];
          return _buildMessageBubble(
            msg: msg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            accent: accent,
            baseColor: baseColor,
          );
        }

        // Optimistic pending user bubble
        final pendingOffset = index - _messages.length;
        if (pendingOffset == 0 && _pendingUserPrompt != null) {
          return _buildUserBubble(
            content: _pendingUserPrompt!,
            timestamp: _pendingUserTime ?? DateTime.now(),
            accent: accent,
          );
        }

        // Typing indicator bubble
        return _buildTypingIndicator(
          accent: accent,
          baseColor: baseColor,
          textSecondary: textSecondary,
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required ChatMessage msg,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color baseColor,
  }) {
    final isUser = msg.sender == 'user';

    if (isUser) {
      return _buildUserBubble(
        content: msg.content,
        timestamp: msg.createdAt,
        accent: accent,
      );
    }

    return _buildAssistantBubble(
      content: msg.content,
      timestamp: msg.createdAt,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      baseColor: baseColor,
    );
  }

  Widget _buildUserBubble({
    required String content,
    required DateTime timestamp,
    required Color accent,
  }) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Neumorphic(
            style: NeumorphicStyle(
              depth: 3,
              intensity: 0.85,
              color: accent,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMessageTime(timestamp),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble({
    required String content,
    required DateTime timestamp,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color baseColor,
  }) {
    final maxWidth = MediaQuery.of(context).size.width * 0.80;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Neumorphic(
            style: NeumorphicStyle(
              depth: 3,
              intensity: 0.85,
              color: baseColor,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: content,
                  selectable: true,
                  styleSheet: _buildMarkdownStyleSheet(
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    accent: accent,
                    baseColor: baseColor,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _formatMessageTime(timestamp),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: textSecondary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
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

  MarkdownStyleSheet _buildMarkdownStyleSheet({
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color baseColor,
  }) {
    return MarkdownStyleSheet(
      p: TextStyle(
        fontSize: 14,
        color: textPrimary,
        height: 1.45,
      ),
      strong: TextStyle(
        fontSize: 14,
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      em: TextStyle(
        fontSize: 14,
        color: textPrimary,
        fontStyle: FontStyle.italic,
      ),
      h1: TextStyle(
        fontSize: 17,
        color: textPrimary,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h2: TextStyle(
        fontSize: 15.5,
        color: textPrimary,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h3: TextStyle(
        fontSize: 14.5,
        color: textPrimary,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      listBullet: TextStyle(
        fontSize: 14,
        color: accent,
        fontWeight: FontWeight.bold,
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        color: accent,
        backgroundColor: textSecondary.withValues(alpha: 0.12),
      ),
      codeblockDecoration: BoxDecoration(
        color: textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      blockquote: TextStyle(
        fontSize: 13.5,
        color: textSecondary,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
      tableHead: TextStyle(
        fontSize: 13,
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      tableBody: TextStyle(
        fontSize: 13,
        color: textPrimary,
      ),
      tableBorder: TableBorder.all(
        color: textSecondary.withValues(alpha: 0.2),
        width: 1,
      ),
      pPadding: const EdgeInsets.only(bottom: 4),
      listIndent: 20.0,
    );
  }

  Widget _buildTypingIndicator({
    required Color accent,
    required Color baseColor,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Neumorphic(
          style: NeumorphicStyle(
            depth: 2,
            intensity: 0.8,
            color: baseColor,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              _TypingDots(color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated 3-dots typing indicator mimicking realistic chat generation.
class _TypingDots extends StatefulWidget {
  final Color color;

  const _TypingDots({required this.color});

  static const double dotSize = 5.5;
  static const double spacing = 3.5;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    final start = index * 0.2;
    final end = start + 0.6;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        final bounce = (progress < 0.5) ? progress * 2 : (1.0 - progress) * 2;
        return Opacity(
          opacity: 0.35 + (0.65 * bounce),
          child: Transform.translate(
            offset: Offset(0, -3.5 * bounce),
            child: Container(
              width: _TypingDots.dotSize,
              height: _TypingDots.dotSize,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        const SizedBox(width: _TypingDots.spacing),
        _buildDot(1),
        const SizedBox(width: _TypingDots.spacing),
        _buildDot(2),
      ],
    );
  }
}

