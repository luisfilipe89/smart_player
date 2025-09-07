import 'package:flutter/material.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/screens/auth/auth_screen.dart';
import 'package:move_young/screens/main_scaffold.dart';
import 'package:move_young/theme/tokens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),

              // Logo/Title Section
              Column(
                children: [
                  // App Icon/Logo placeholder
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppRadius.bigContainer),
                      boxShadow: AppShadows.md,
                    ),
                    child: const Icon(
                      Icons.sports_basketball,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // App Title
                  Text(
                    'SMARTPLAYER',
                    style: AppTextStyles.huge.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Subtitle
                  Text(
                    'Find, organize, and join sports games near you',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.grey,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const Spacer(),

              // Auth Buttons Section
              Column(
                children: [
                  // Continue with Apple
                  _buildSocialButton(
                    context: context,
                    icon: Icons.apple,
                    label: 'Continue with Apple',
                    onPressed: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Continue with Google
                  _buildSocialButton(
                    context: context,
                    icon: Icons.g_mobiledata,
                    label: 'Continue with Google',
                    onPressed: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Continue with Facebook
                  _buildSocialButton(
                    context: context,
                    icon: Icons.facebook,
                    label: 'Continue with Facebook',
                    onPressed: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.grey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: Text(
                          'or',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.grey)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Continue with Email
                  _buildEmailButton(context),
                  const SizedBox(height: AppSpacing.md),

                  // Skip for now (anonymous)
                  TextButton(
                    onPressed: () => _continueAnonymously(context),
                    child: Text(
                      'Skip for now',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.grey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: AppTextStyles.button.copyWith(
            color: AppColors.text,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.text,
          elevation: 2,
          shadowColor: AppColors.blackShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: const BorderSide(color: AppColors.lightgrey),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () => _showEmailAuth(context),
        icon: const Icon(Icons.email, size: 24),
        label: const Text('Continue with Email'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.blackShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }

  void _showEmailAuth(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
    );

    if (result == true && context.mounted) {
      _navigateToMainApp(context);
    }
  }

  void _continueAnonymously(BuildContext context) async {
    try {
      await AuthService.signInAnonymously();
      if (context.mounted) {
        _navigateToMainApp(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToMainApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainScaffold(),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon! Use email for now.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
