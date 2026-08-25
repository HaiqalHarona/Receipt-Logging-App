import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../../services/onboarding_service.dart';
import '../../../../services/legal_document_service.dart';
import '../../../../services/app_logger_service.dart';
import '../../../core/widgets/app_snack_bar.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _agreedToTerms = false;
  bool _isCompleting = false;

  final int _totalPages = 4;

  @override
  void initState() {
    super.initState();
    _agreedToTerms = OnboardingService.instance.hasAcceptedLegalTerms;
    AppLogger.info('UI', 'OnboardingScreen initialized (termsAccepted=$_agreedToTerms)');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _onComplete() async {
    if (!_agreedToTerms) {
      AppSnackBar.show(
        context,
        message:
            'Please accept the Terms of Service and Privacy Policy to continue.',
        isError: true,
      );
      return;
    }

    setState(() => _isCompleting = true);
    await OnboardingService.instance.completeOnboarding(acceptLegal: true);
    if (!mounted) return;

    AppLogger.info('UI', 'User completed onboarding flow. Navigating to dashboard.');
    context.go('/dashboard');
  }

  void _openLegalDocument(LegalDocType type) {
    AppLogger.info('UI', 'User opened legal document from onboarding: ${type.name}');
    context.push('/legal/${type.name}');
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;

    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final baseColor = controller.currentBaseColor;
        final fontScale = controller.fontScale;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Top Header / Skip Button / Back Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (canPop) ...[
                              NeumorphicButton(
                                onPressed: () {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  } else {
                                    context.go('/dashboard');
                                  }
                                },
                                style: NeumorphicStyle(
                                  shape: NeumorphicShape.convex,
                                  boxShape: const NeumorphicBoxShape.circle(),
                                  depth: 3,
                                  intensity: 0.8,
                                  color: baseColor,
                                ),
                                padding: const EdgeInsets.all(7),
                                child: Icon(Icons.arrow_back_rounded,
                                    color: textPrimary, size: 18),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Icon(Icons.receipt_long_rounded, color: accent, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Receipt Logger',
                              style: TextStyle(
                                fontSize: 16 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (_currentPage < _totalPages - 1)
                          TextButton(
                            onPressed: () {
                              _pageController.animateToPage(
                                _totalPages - 1,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 13 * fontScale,
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 36),
                      ],
                    ),
                  ),

                  // Carousel View
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (idx) => setState(() => _currentPage = idx),
                      children: [
                        _buildSlide(
                          icon: Icons.lock_outline_rounded,
                          badge: '100% Offline-First Privacy',
                          title: 'Your Financial Data\nBelongs to You',
                          description:
                              'In Guest Mode, all receipts, expenses, and chat history are saved locally only. Zero tracking and no cloud lock-in.',
                          baseColor: baseColor,
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          fontScale: fontScale,
                        ),
                        _buildSlide(
                          icon: Icons.document_scanner_rounded,
                          badge: 'Fast AI Vision OCR',
                          title: 'Lightning-Fast\nReceipt Extraction',
                          description:
                              'Snap paper receipts or import gallery invoices. State-of-the-art vision models extract merchants, line items, taxes, and totals in seconds.',
                          baseColor: baseColor,
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          fontScale: fontScale,
                        ),
                        _buildSlide(
                          icon: Icons.auto_awesome_rounded,
                          badge: 'Zero-Training Guarantee',
                          title: 'Smart Financial\nAssistant',
                          description:
                              'Ask spending questions, discover category breakdowns, and export reports anytime. Your data is strictly private and never used to train foundation models.',
                          baseColor: baseColor,
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          fontScale: fontScale,
                        ),
                        _buildLegalConsentSlide(
                          baseColor: baseColor,
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          fontScale: fontScale,
                        ),
                      ],
                    ),
                  ),

                  // Bottom Navigation Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        // Dot Indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_totalPages, (index) {
                            final isSelected = _currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: isSelected ? 24 : 8,
                              decoration: BoxDecoration(
                                color: isSelected ? accent : textSecondary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        if (_currentPage < _totalPages - 1)
                          SizedBox(
                            width: double.infinity,
                            child: NeumorphicButton(
                              onPressed: _onNext,
                              style: NeumorphicStyle(
                                depth: 4,
                                intensity: 0.85,
                                boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(16)),
                                color: baseColor,
                                border: NeumorphicBorder(
                                  color: accent.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Continue',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 15 * fontScale,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded,
                                        color: accent, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: NeumorphicButton(
                              onPressed: _isCompleting ? null : _onComplete,
                              style: NeumorphicStyle(
                                depth: _agreedToTerms ? 4 : 1,
                                intensity: 0.85,
                                boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(16)),
                                color: _agreedToTerms
                                    ? accent
                                    : baseColor,
                                border: NeumorphicBorder(
                                  color: accent.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: _isCompleting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'I Agree & Get Started',
                                        style: TextStyle(
                                          color: _agreedToTerms
                                              ? Colors.white
                                              : textPrimary,
                                          fontSize: 15 * fontScale,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
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

  Widget _buildSlide({
    required IconData icon,
    required String badge,
    required String title,
    required String description,
    required Color baseColor,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required double fontScale,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Neumorphic(
            style: NeumorphicStyle(
              depth: 6,
              intensity: 0.9,
              boxShape: const NeumorphicBoxShape.circle(),
              color: baseColor,
              border: NeumorphicBorder(
                color: accent.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: Icon(icon, size: 54, color: accent),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: accent,
                fontSize: 12 * fontScale,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24 * fontScale,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14 * fontScale,
              color: textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLegalConsentSlide({
    required Color baseColor,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required double fontScale,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Neumorphic(
              style: NeumorphicStyle(
                depth: 5,
                intensity: 0.85,
                boxShape: const NeumorphicBoxShape.circle(),
                color: baseColor,
                border: NeumorphicBorder(
                  color: accent.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Icon(Icons.verified_user_outlined, size: 36, color: accent),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Terms & Privacy Consent',
              style: TextStyle(
                fontSize: 20 * fontScale,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Please review our compliance policies before starting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13 * fontScale,
                color: textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 18),

          _buildLegalDocTile(
            title: 'Privacy Policy',
            subtitle: 'GDPR, CCPA/CPRA, Zero AI Training & Encryption',
            icon: Icons.security_rounded,
            type: LegalDocType.privacy,
            baseColor: baseColor,
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            fontScale: fontScale,
          ),
          const SizedBox(height: 8),
          _buildLegalDocTile(
            title: 'Terms of Service',
            subtitle: 'Acceptable use, AI disclaimers & governing law',
            icon: Icons.gavel_rounded,
            type: LegalDocType.terms,
            baseColor: baseColor,
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            fontScale: fontScale,
          ),
          const SizedBox(height: 8),
          _buildLegalDocTile(
            title: 'Cookie & Storage Policy',
            subtitle: 'Local database, security tokens & cache details',
            icon: Icons.cookie_outlined,
            type: LegalDocType.cookies,
            baseColor: baseColor,
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            fontScale: fontScale,
          ),
          const SizedBox(height: 8),
          _buildLegalDocTile(
            title: 'Accessibility Statement',
            subtitle: 'ADA Title III, WCAG 2.1 AA & contrast support',
            icon: Icons.accessibility_new_rounded,
            type: LegalDocType.accessibility,
            baseColor: baseColor,
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            fontScale: fontScale,
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Circular Neumorphic Checkmark that indents on select
                Neumorphic(
                  style: NeumorphicStyle(
                    shape: _agreedToTerms
                        ? NeumorphicShape.concave
                        : NeumorphicShape.convex,
                    boxShape: const NeumorphicBoxShape.circle(),
                    depth: _agreedToTerms ? -3.5 : 3.5,
                    intensity: 0.9,
                    color: _agreedToTerms
                        ? accent.withValues(alpha: 0.22)
                        : baseColor,
                    border: NeumorphicBorder(
                      color: _agreedToTerms
                          ? accent
                          : textSecondary.withValues(alpha: 0.4),
                      width: _agreedToTerms ? 1.8 : 1.2,
                    ),
                  ),
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: Center(
                      child: _agreedToTerms
                          ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: accent,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I confirm that I am at least 13 years old (16 in the EEA/UK) and agree to the Terms of Service and Privacy Policy.',
                    style: TextStyle(
                      fontSize: 12.5 * fontScale,
                      color: textPrimary,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLegalDocTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required LegalDocType type,
    required Color baseColor,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required double fontScale,
  }) {
    return NeumorphicButton(
      onPressed: () => _openLegalDocument(type),
      style: NeumorphicStyle(
        depth: 2,
        intensity: 0.8,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
        color: baseColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11 * fontScale,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: textSecondary, size: 13),
        ],
      ),
    );
  }
}
