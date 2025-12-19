import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/services/connectivity/connectivity_provider.dart';
import 'package:move_young/features/auth/screens/auth_screen.dart';
import 'package:move_young/navigation/main_scaffold.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/services/firebase_error_handler.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _loadingGoogle = false;

  bool get _isLoading => _loadingGoogle;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF181e35),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),

              // Logo/Title Section
              Column(
                children: [
                  // App Logo
                  Container(
                    color: const Color(
                        0xFF181e35), // Match screen background exactly
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image fails to load
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              AppRadius.bigContainer,
                            ),
                          ),
                          child: const Icon(
                            Icons.sports_basketball,
                            size: 60,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),

                  // App Title (kept as brand; if desired, localize key below)
                  Text(
                    'SMARTPLAYER',
                    style: AppTextStyles.huge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Subtitle
                  Text(
                    'introduction'.tr(),
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white70,
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
                  // Continue with Apple (iOS only)
                  if (_isIOS) ...[
                    _buildSocialButton(
                      context: context,
                      icon: _brandIcon('apple'),
                      label: 'auth_continue_apple'.tr(),
                      onPressed:
                          _isLoading ? null : () => _showComingSoon(context),
                      loading: false,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Continue with Google
                  _buildSocialButton(
                    context: context,
                    icon: _brandIcon('google'),
                    label: 'auth_continue_google'.tr(),
                    onPressed:
                        _isLoading ? null : () => _continueWithGoogle(context),
                    loading: _loadingGoogle,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white30)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          'auth_or'.tr(),
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Colors.white30)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Continue with Email
                  _buildEmailButton(context, disabled: _isLoading),
                  const SizedBox(height: AppSpacing.md),
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
    required Widget icon,
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
            : icon,
        label: loading
            ? Text('auth_please_wait'.tr())
            : Text(
                label,
                style: AppTextStyles.button.copyWith(color: AppColors.text),
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
        label: Text('auth_continue_email'.tr()),
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
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AuthScreen()));

    if (result == true && context.mounted) {
      _navigateToMainApp(context);
    }
  }

  void _continueWithGoogle(BuildContext context) async {
    setState(() => _loadingGoogle = true);
    bool navigated = false;
    try {
      // Check active internet connection before starting Google sign-in
      final hasInternet =
          await ref.read(connectivityActionsProvider).hasInternetConnection();
      if (!hasInternet) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('error_network'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final authActions = ref.read(authActionsProvider);
      final credential = await authActions.signInWithGoogle();
      if (credential != null && context.mounted) {
        navigated = true;
        _navigateToMainApp(context);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('auth_google_cancelled'.tr()),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final errorMessage = FirebaseErrorHandler.getUserMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (!navigated && mounted) setState(() => _loadingGoogle = false);
    }
  }

  void _navigateToMainApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScaffold(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('auth_coming_soon'.tr()),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _brandIcon(String brand) {
    switch (brand) {
      case 'apple':
        return const FaIcon(FontAwesomeIcons.apple, size: 22);
      case 'google':
      default:
        return const FaIcon(FontAwesomeIcons.google, size: 22);
    }
  }
}
