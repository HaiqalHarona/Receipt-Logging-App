import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/app_theme.dart';

class GoogleUsernamePromptSheet extends StatefulWidget {
  final String suggestedUsername;
  final String email;

  const GoogleUsernamePromptSheet({
    super.key,
    required this.suggestedUsername,
    required this.email,
  });

  @override
  State<GoogleUsernamePromptSheet> createState() =>
      _GoogleUsernamePromptSheetState();
}

class _GoogleUsernamePromptSheetState extends State<GoogleUsernamePromptSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.suggestedUsername);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Username cannot be empty.');
      return;
    }
    if (text.length < 3 || text.length > 10) {
      setState(
          () => _error = 'Username must be between 3 and 10 characters.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{3,10}$').hasMatch(text)) {
      setState(() => _error =
          'Letters, numbers, and underscores only.');
      return;
    }

    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final accent = controller.accentColor;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final baseColor = controller.currentBaseColor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Title
          Text(
            "Choose a Username",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Welcome! Complete your Google account setup for ${widget.email} by picking your username.",
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          // Input field
          Neumorphic(
            style: NeumorphicStyle(
              depth: -3,
              intensity: 0.8,
              boxShape: NeumorphicBoxShape.roundRect(
                BorderRadius.circular(12),
              ),
              color: baseColor,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.alternate_email_rounded,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: "Username (3-10 chars)",
                      hintStyle: TextStyle(
                        color: textSecondary.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      counterText: "",
                    ),
                    maxLength: 10,
                    onChanged: (val) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                    onSubmitted: (_) => _onConfirm(),
                  ),
                ),
              ],
            ),
          ),

          // Error banner
          if (_error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: NeumorphicButtonWidget(
              onPressed: _onConfirm,
              child: const Center(
                child: Text(
                  "Complete Sign Up",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
