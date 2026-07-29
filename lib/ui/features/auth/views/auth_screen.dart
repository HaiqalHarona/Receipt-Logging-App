import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeumorphicBackground(
      backendColor: AppTheme.darkBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "🧾 Receipt Logger",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Sign in to sync your expenses",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Email Input
                  _buildInputField(
                    label: "EMAIL ADDRESS",
                    hint: "nino@example.com",
                    icon: Icons.email_rounded,
                  ),
                  const SizedBox(height: 20),

                  // Password Input
                  _buildInputField(
                    label: "PASSWORD",
                    hint: "••••••••••••",
                    icon: Icons.lock_rounded,
                    isObscure: true,
                  ),
                  const SizedBox(height: 32),

                  // Sign In CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                          "Sign In",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    bool isObscure = false,
  }) {
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
            child: Row(
              children: [
                Icon(icon, color: AppTheme.darkTextSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
