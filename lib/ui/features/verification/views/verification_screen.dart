import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeumorphicBackground(
      backendColor: AppTheme.darkBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.darkTextPrimary),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            "Review Receipt",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(label: "MERCHANT NAME", initialValue: "Whole Foods Market"),
                const SizedBox(height: 18),
                _buildInputField(label: "DATE", initialValue: "Jul 30, 2026"),
                const SizedBox(height: 18),
                _buildInputField(label: "TOTAL AMOUNT", initialValue: "\$42.80"),
                const SizedBox(height: 18),
                _buildInputField(label: "CATEGORY", initialValue: "Groceries 🛒"),
                const SizedBox(height: 36),

                // Save Receipt CTA
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: NeumorphicButton(
                    onPressed: () {
                      context.go('/dashboard');
                    },
                    style: NeumorphicStyle(
                      color: AppTheme.darkAccentPinkishRed,
                      boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
                    ),
                    child: const Center(
                      child: Text(
                        "Save Receipt",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Rescan CTA
                Center(
                  child: TextButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: const Text(
                      "Rescan Receipt",
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 14,
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

  Widget _buildInputField({required String label, required String initialValue}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Neumorphic(
          style: NeumorphicStyle(
            depth: -3,
            intensity: 0.6,
            color: AppTheme.darkCardBackground,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                initialValue,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
