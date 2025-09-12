import 'package:flutter/material.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/screens/auth/auth_screen.dart';
import 'package:move_young/screens/main_scaffold.dart';
import 'package:move_young/theme/tokens.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loadingGoogle = false;
  bool _loadingAnon = false;

  bool get _isLoading => _loadingGoogle || _loadingAnon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF6FAFF),
                Color(0xFFEFF6FF),
              ],
            ),
          ),
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
                      onPressed:
                          _isLoading ? null : () => _showComingSoon(context),
                      loading: false,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Continue with Google
                    _buildSocialButton(
                      context: context,
                      icon: Icons.g_mobiledata,
                      label: 'Continue with Google',
                      onPressed: _isLoading
                          ? null
                          : () => _continueWithGoogle(context),
                      loading: _loadingGoogle,
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
                    _buildEmailButton(context, disabled: _isLoading),
                    const SizedBox(height: AppSpacing.md),

                    // Skip for now (anonymous)
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => _continueAnonymously(context),
                      child: _loadingAnon
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
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
      ),
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 24),
        label: loading
            ? const Text('Please wait...')
            : Text(
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

  Widget _buildEmailButton(BuildContext context, {bool disabled = false}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : () => _showEmailAuth(context),
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
    setState(() => _loadingAnon = true);
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
    } finally {
      if (mounted) setState(() => _loadingAnon = false);
    }
  }

  void _continueWithGoogle(BuildContext context) async {
    setState(() => _loadingGoogle = true);
    try {
      final credential = await AuthService.signInWithGoogle();
      if (credential != null && context.mounted) {
        _navigateToMainApp(context);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in cancelled'),
            backgroundColor: AppColors.primary,
          ),
        );
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
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
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
