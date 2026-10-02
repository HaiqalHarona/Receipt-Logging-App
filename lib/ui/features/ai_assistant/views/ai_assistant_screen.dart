// File: lib/ui/features/ai_assistant/views/ai_assistant_screen.dart

import 'dart:async';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../domain/models/conversation.dart';
import '../../../../services/app_logger_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/fading_edge_scroll_view.dart';
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
    final isYesterday =
        now.subtract(const Duration(days: 1)).year == localDt.year &&
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

        return AppGradientBackground(
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
                              child: Text.rich(
                                TextSpan(
                                  text: "Conversations",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: " (${allConversations.length})",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // "+" New Chat Action Button (outlined, protruded, not filled)
                            NeumorphicCircularButton(
                              icon: Icons.add_rounded,
                              onTap: _handleCreateNewChat,
                              depth: controller.neuDepth,
                              color: baseColor,
                              iconColor: accent,
                              padding: 10,
                              iconSize: 20,
                              border: NeumorphicBorder(
                                color: accent,
                                width: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Indented Search Bar
                        Neumorphic(
                          style: NeumorphicStyle(
                            depth: -(controller.neuDepth.clamp(1.5, 3.5)),
                            intensity: controller.isDarkMode ? 0.45 : 0.8,
                            color: controller.isDarkMode
                                ? Color.alphaBlend(
                                    Colors.black.withValues(alpha: 0.15),
                                    baseColor)
                                : baseColor,
                            shadowDarkColorEmboss:
                                controller.shadowDarkColorEmboss,
                            shadowLightColorEmboss:
                                controller.shadowLightColorEmboss,
                            boxShape: NeumorphicBoxShape.roundRect(
                                BorderRadius.circular(14)),
                            border: NeumorphicBorder(
                              color: controller.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 0.8,
                            ),
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
                                    hintText:
                                        "Search conversation title, date...",
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
                            depth: controller.neuDepth,
                          )
                        : FadingEdgeScrollView(
                            fadeHeightTop: 20,
                            fadeHeightBottom: 28,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: EdgeInsets.only(
                                left: 24,
                                right: 24,
                                top: 8,
                                bottom: AppBottomNavBar.contentBottomPadding(
                                    context,
                                    extraMargin: 24.0),
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
    required double depth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  (constraints.maxHeight - 80).clamp(0.0, double.infinity),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Neumorphic(
                    style: NeumorphicStyle(
                      depth: depth,
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
          ),
        );
      },
    );
  }
}
