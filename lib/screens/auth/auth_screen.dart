// lib/screens/auth/auth_screen_migrated.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/services/auth_provider.dart';
import 'package:move_young/providers/services/connectivity_provider.dart';
import 'package:move_young/services/error_handler_service.dart';
import 'package:move_young/theme/tokens.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool startWithRegistration;

  const AuthScreen({super.key, this.startWithRegistration = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  late bool _isLogin;
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

    // Check connectivity before attempting auth
    final hasConnection = ref.read(hasConnectionProvider);
    if (!hasConnection) {
      ErrorHandlerService.showError(context, 'error_network');
      return;
    }

    try {
      // Ensure no existing session (including anonymous) masks a failed login
      if (_isLogin && ref.read(isSignedInProvider)) {
        await ref.read(authActionsProvider).signOut();
      }

      if (_isLogin) {
        await ref.read(authActionsProvider).signInWithEmailAndPassword(
              _emailController.text.trim(),
              _passwordController.text,
            );
      } else {
        await ref.read(authActionsProvider).createUserWithEmailAndPassword(
              _emailController.text.trim(),
              _passwordController.text,
              _nameController.text.trim(),
            );
      }

      // Success - navigation will be handled by the auth state listener
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e, stack) {
      ErrorHandlerService.logError(e, stack);
      if (mounted) {
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Check connectivity before attempting auth
    final hasConnection = ref.read(hasConnectionProvider);
    if (!hasConnection) {
      ErrorHandlerService.showError(context, 'error_network');
      return;
    }

    try {
      await ref.read(authActionsProvider).signInWithGoogle();
      // Success - navigation will be handled by the auth state listener
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e, stack) {
      ErrorHandlerService.logError(e, stack);
      if (mounted) {
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _handleAnonymousSignIn() async {
    // Check connectivity before attempting auth
    final hasConnection = ref.read(hasConnectionProvider);
    if (!hasConnection) {
      ErrorHandlerService.showError(context, 'error_network');
      return;
    }

    try {
      await ref.read(authActionsProvider).signInAnonymously();
      // Success - navigation will be handled by the auth state listener
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e, stack) {
      ErrorHandlerService.logError(e, stack);
      if (mounted) {
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state to show loading indicator
    final authAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo or app name
                    Text(
                      'app_name'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'app_tagline'.tr(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Auth form
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Title
                              Text(
                                _isLogin ? 'sign_in'.tr() : 'sign_up'.tr(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // Name field (only for registration)
                              if (!_isLogin) ...[
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'name'.tr(),
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'name_required'.tr();
                                    }
                                    if (value.trim().length < 2) {
                                      return 'name_too_short'.tr();
                                    }
                                    if (_containsInappropriateContent(
                                        value.trim())) {
                                      return 'name_inappropriate'.tr();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'email'.tr(),
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'email_required'.tr();
                                  }
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value.trim())) {
                                    return 'email_invalid'.tr();
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'password'.tr(),
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'password_required'.tr();
                                  }
                                  if (value.length < 6) {
                                    return 'password_too_short'.tr();
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Auth button
                              ElevatedButton(
                                onPressed:
                                    authAsync.isLoading ? null : _handleAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: authAsync.isLoading
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
                                        _isLogin
                                            ? 'sign_in'.tr()
                                            : 'sign_up'.tr(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),

                              // Google sign in button
                              OutlinedButton.icon(
                                onPressed: authAsync.isLoading
                                    ? null
                                    : _handleGoogleSignIn,
                                icon:
                                    const Icon(Icons.login, color: Colors.red),
                                label: Text('sign_in_with_google'.tr()),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Anonymous sign in button
                              TextButton(
                                onPressed: authAsync.isLoading
                                    ? null
                                    : _handleAnonymousSignIn,
                                child: Text('continue_anonymously'.tr()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle between login and registration
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'no_account'.tr() : 'have_account'.tr(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
                    child: Text(
                      _isLogin ? 'sign_up'.tr() : 'sign_in'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
