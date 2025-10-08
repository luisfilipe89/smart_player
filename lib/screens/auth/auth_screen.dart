import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/theme/tokens.dart';

class AuthScreen extends StatefulWidget {
  final bool startWithRegistration;

  const AuthScreen({super.key, this.startWithRegistration = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  late bool _isLogin;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.startWithRegistration;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Returns a simplified lowercase-only string for safer checks
  String _normalizeNameForCheck(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z]"), ""); // keep letters only
  }

  // Very small client-side filter to reduce obvious offensive or misleading names
  bool _containsInappropriateContent(String name) {
    final normalized = _normalizeNameForCheck(name);

    // Commonly abused or misleading terms and basic profanity
    const banned = <String>{
      // misleading roles
      'admin', 'administrator', 'moderator', 'mod', 'owner', 'support', 'staff',
      // obvious placeholders
      'test', 'testing', 'guest', 'anonymous', 'anon', 'unknown', 'user',
      'null', 'undefined',
      // basic profanity (keep minimal to avoid heavy false positives)
      'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy', 'cunt', 'whore',
      'slut',
      // hate / slurs (non-exhaustive; just a small client-side guard)
      'nazi', 'hitler', 'isis', 'terrorist',
      // harm
      'suicide', 'murder', 'kill',
    };

    // Reject exact matches or clearly contained standalone banned terms
    for (final word in banned) {
      if (normalized == word) return true;
      // also block contains when the banned word is long enough to be deliberate
      if (word.length >= 4 && normalized.contains(word)) return true;
    }

    return false;
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await AuthService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        // If user has no display name yet, prompt for first name once
        final user = AuthService.currentUser;
        final hasName = (user?.displayName?.trim().isNotEmpty ?? false);
        if (!hasName && mounted) {
          final suggested = _emailController.text.trim().split('@').first;
          final controller = TextEditingController(text: suggested);
          final entered = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text('auth_first_name'.tr()),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'auth_first_name'.tr(),
                ),
                textInputAction: TextInputAction.done,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text('cancel'.tr(), overflow: TextOverflow.ellipsis),
                ),
                TextButton(
                  onPressed: () {
                    final v = controller.text.trim();
                    Navigator.of(ctx)
                        .pop(v.isEmpty ? null : v.split(RegExp(r"\\s+")).first);
                  },
                  child: Text('ok'.tr(), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          );
          if (entered != null && entered.length >= 2 && mounted) {
            await AuthService.updateDisplayName(entered);
          }
        }
      } else {
        // Create account and set first name in one step
        await AuthService.createUserWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
        // Ensure latest profile is loaded
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('already_signed_in'.tr()),
            backgroundColor: AppColors.primary,
          ),
        );
        // Use a timer instead of await to avoid context usage across async gaps
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } catch (e) {
      if (mounted) {
        // If already authenticated, inform and close
        if (AuthService.isSignedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('already_signed_in')),
              backgroundColor: AppColors.primary,
            ),
          );
          // Use a timer instead of await to avoid context usage across async gaps
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
          return;
        }
        String raw = e.toString();
        raw = raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
        final localized = tr(raw);
        final message = localized == raw
            ? (_isLogin
                ? tr('error_generic_signin')
                : tr('error_generic_signup'))
            : localized;

        // If trying to sign up but email is already in use, switch to Sign In view
        if (!_isLogin && raw == 'error_email_in_use') {
          setState(() {
            _isLogin = true;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  _isLogin
                      ? 'auth_signin_title'.tr()
                      : 'auth_signup_title'.tr(),
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isLogin ? 'auth_signin_sub'.tr() : 'auth_signup_sub'.tr(),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Name field (only for signup)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'auth_first_name'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'auth_name_required'.tr();
                      }

                      final name = value.trim();

                      // length limits
                      if (name.length < 2) {
                        return 'auth_name_too_short'.tr();
                      }
                      if (name.length > 20) {
                        return 'auth_name_too_long'.tr();
                      }

                      // allow common letters incl. basic latin accents, spaces, apostrophes and hyphens
                      final validChars = RegExp(r"^[A-Za-zÀ-ÿ' -]+");
                      if (!validChars.hasMatch(name)) {
                        return 'auth_name_invalid'.tr();
                      }

                      if (_containsInappropriateContent(name)) {
                        return 'auth_name_inappropriate'.tr();
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'auth_email'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'auth_email_required'.tr();
                    }
                    if (!value.contains('@')) {
                      return 'auth_email_invalid'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'auth_password'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.grey,
                      ),
                      tooltip:
                          _obscurePassword ? 'Show password' : 'Hide password',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth_password_required'.tr();
                    }
                    if (value.length < 6) {
                      return 'auth_password_too_short'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Forgot password (only for login)
                if (_isLogin) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final email = _emailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('auth_email_invalid'.tr()),
                                  ),
                                );
                                return;
                              }
                              final scaffoldMessenger =
                                  ScaffoldMessenger.of(context);
                              try {
                                await AuthService.sendPasswordResetEmail(email);
                                if (!mounted) return;
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tr('settings_reset_email_sent',
                                          args: [email]),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                String errorMessage = e.toString().replaceFirst(
                                    RegExp(r'^Exception:\s*'), '');
                                String localizedError = tr(errorMessage);
                                if (localizedError == errorMessage) {
                                  localizedError = tr('error_generic_reset');
                                }
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(localizedError),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      child: Text('auth_forgot_password'.tr()),
                    ),
                  ),
                ],

                // Auth button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isLogin ? 'auth_signin'.tr() : 'auth_signup'.tr(),
                          style: AppTextStyles.button,
                        ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Toggle between login/signup
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() => _isLogin = !_isLogin);
                        },
                  child: Text(
                    _isLogin
                        ? 'auth_toggle_to_signup'.tr()
                        : 'auth_toggle_to_signin'.tr(),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl), // Extra space at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }
}
