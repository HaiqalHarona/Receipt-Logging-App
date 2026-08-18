// File: lib/ui/features/ai_assistant/views/ai_assistant_screen.dart

import 'dart:async';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../domain/models/conversation.dart';
import '../../../../services/app_logger_service.dart';
import '../../../core/theme/theme_controller.dart';
import 'widgets/conversation_list_item_widget.dart';

/// Screen displaying the list of AI chat conversations with search functionality,
/// "+ New Chat" action, and 3-dots popup menu on each item.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AppLogger.info('UI', 'AiAssistantScreen (Conversations List) initialized');
    ConversationRepository.instance.init();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.trim().toLowerCase();
        });
      }
    });
  }

  String _formatDateForSearch(DateTime dt) {
    final localDt = dt.toLocal();
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december'
    ];
    const shortMonths = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec'
    ];

    final now = DateTime.now();
    final isToday = now.year == localDt.year &&
        now.month == localDt.month &&
        now.day == localDt.day;
    final isYesterday = now.subtract(const Duration(days: 1)).year == localDt.year &&
        now.subtract(const Duration(days: 1)).month == localDt.month &&
        now.subtract(const Duration(days: 1)).day == localDt.day;

    final monthIndex = localDt.month - 1;
    final parts = [
      localDt.year.toString(),
      months[monthIndex],
      shortMonths[monthIndex],
      localDt.day.toString(),
      if (isToday) 'today',
      if (isYesterday) 'yesterday',
    ];

    return parts.join(' ');
  }

  List<Conversation> _filterConversations(List<Conversation> all) {
    if (_searchQuery.isEmpty) return all;

    return all.where((c) {
      final titleMatch = c.title.toLowerCase().contains(_searchQuery);
      final dateSearchStr = _formatDateForSearch(c.updatedAt);
      final dateMatch = dateSearchStr.contains(_searchQuery);
      return titleMatch || dateMatch;
    }).toList();
  }

  void _handleCreateNewChat() {
    AppLogger.info('UI', 'Navigating to new empty conversation');
    context.push('/chat');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        AppThemeController.instance,
        ConversationRepository.instance,
      ]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final baseColor = controller.currentBaseColor;

        final allConversations = ConversationRepository.instance.conversations;
        final filteredList = _filterConversations(allConversations);

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fixed Top Controls Block (Header & Search) ──
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 24, right: 24, top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row with Title, Count, and "+" New Chat Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Conversations",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "All logged chats (${allConversations.length} records)",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // "+" New Chat Action Button
                            NeumorphicButton(
                              onPressed: _handleCreateNewChat,
                              style: NeumorphicStyle(
                                depth: 3,
                                intensity: 0.85,
                                color: accent,
                                boxShape: const NeumorphicBoxShape.circle(),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Indented Search Bar
                        Neumorphic(
                          style: NeumorphicStyle(
                            depth: -3,
                            intensity: 0.8,
                            color: baseColor,
                            boxShape: NeumorphicBoxShape.roundRect(
                                BorderRadius.circular(14)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  color: textSecondary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: InputDecoration(
                                    hintText: "Search conversation title, date...",
                                    hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: textSecondary.withValues(
                                            alpha: 0.7)),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: textSecondary, size: 18),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // ── Scrollable Conversations List ──
                  Expanded(
                    child: filteredList.isEmpty
                        ? _buildEmptyState(
                            isSearching: _searchQuery.isNotEmpty,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            accent: accent,
                            baseColor: baseColor,
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(
                              left: 24,
                              right: 24,
                              top: 8,
                              bottom: 110, // Avoid bottom nav overlap
                            ),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final conv = filteredList[index];
                              return ConversationListItemWidget(
                                conversation: conv,
                                onTap: () {
                                  AppLogger.info('UI',
                                      'User tapped conversation: ${conv.id} ("${conv.title}")');
                                  context.push('/chat', extra: conv);
                                },
                              );
                            },
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

  Widget _buildEmptyState({
    required bool isSearching,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color baseColor,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Neumorphic(
              style: NeumorphicStyle(
                depth: 3,
                intensity: 0.8,
                boxShape: const NeumorphicBoxShape.circle(),
                color: baseColor,
              ),
              padding: const EdgeInsets.all(24),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 40,
                color: accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching
                  ? "No matching conversations"
                  : "No conversations yet",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? "Try searching for a different title, month, or date."
                  : "Tap '+' to start a spending inquiry with your AI assistant.",
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
