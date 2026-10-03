import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/fading_edge_scroll_view.dart';
import '../../../../services/legal_document_service.dart';
import '../../../../services/app_logger_service.dart';

class LegalDocumentScreen extends StatefulWidget {
  final LegalDocType initialDocType;

  const LegalDocumentScreen({
    super.key,
    this.initialDocType = LegalDocType.privacy,
  });

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late LegalDocType _selectedDocType;
  bool _isLoading = true;
  String _markdownContent = '';

  @override
  void initState() {
    super.initState();
    _selectedDocType = widget.initialDocType;
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    try {
      final content =
          await LegalDocumentService.instance.loadDocument(_selectedDocType);
      if (mounted) {
        setState(() {
          _markdownContent = content;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      AppLogger.error('LegalScreen', 'Failed to load legal document', e, st);
      if (mounted) {
        setState(() {
          _markdownContent =
              '# ${_selectedDocType.title}\n\nFailed to load document content.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSelectTab(LegalDocType type) {
    if (_selectedDocType == type) return;
    setState(() {
      _selectedDocType = type;
    });
    _loadDocument();
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
        final fontScale = controller.fontScale;

        return AppGradientBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Standardized Custom Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        NeumorphicCircularButton(
                          icon: Icons.arrow_back_rounded,
                          iconSize: 20,
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/dashboard');
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            _selectedDocType.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16 * fontScale,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                // Top Segmented Document Selector Tabs with unclipped shadow padding
                Container(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: LegalDocType.values.map((type) {
                        final isSelected = _selectedDocType == type;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: NeumorphicFilterChip(
                            isSelected: isSelected,
                            onTap: () => _onSelectTab(type),
                            restDepth: 3.5,
                            selectedDepth: -2.0,
                            borderRadius: BorderRadius.circular(12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                            child: Text(
                              type == LegalDocType.cookies
                                  ? 'Cookies'
                                  : (type == LegalDocType.accessibility
                                      ? 'Accessibility'
                                      : type.title),
                              style: TextStyle(
                                fontSize: 13 * fontScale,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected ? accent : textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),

                // Main Markdown View Area
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        )
                      : FadingEdgeScrollView(
                          fadeHeightTop: 20,
                          fadeHeightBottom: 28,
                          child: Markdown(
                            data: _markdownContent,
                            selectable: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            styleSheet: MarkdownStyleSheet(
                              h1: TextStyle(
                                fontSize: 22 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                height: 1.3,
                              ),
                              h2: TextStyle(
                                fontSize: 18 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: accent,
                                height: 1.4,
                              ),
                              h3: TextStyle(
                                fontSize: 15 * fontScale,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                                height: 1.4,
                              ),
                              p: TextStyle(
                                fontSize: 14 * fontScale,
                                color: textSecondary,
                                height: 1.6,
                              ),
                              listBullet: TextStyle(
                                fontSize: 14 * fontScale,
                                color: accent,
                              ),
                              tableHead: TextStyle(
                                fontSize: 13 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                              tableBody: TextStyle(
                                fontSize: 12.5 * fontScale,
                                color: textSecondary,
                              ),
                              tableBorder: TableBorder.all(
                                color: textSecondary.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              code: TextStyle(
                                fontSize: 13 * fontScale,
                                color: accent,
                                backgroundColor: baseColor,
                              ),
                              blockquote: TextStyle(
                                fontSize: 13.5 * fontScale,
                                fontStyle: FontStyle.italic,
                                color: textSecondary,
                              ),
                              horizontalRuleDecoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: textSecondary.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
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
      },
    );
  }
}
