import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/theme/app_back_button.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('help_privacy'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: AppPaddings.symmHorizontalReg.copyWith(
            top: AppSpacing.lg,
            bottom: AppSpacing.lg,
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.container),
                boxShadow: AppShadows.md,
              ),
              padding: AppPaddings.allBig,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('help_privacy'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Last updated: September 2025',
                    style: AppTextStyles.smallMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'SmartPlayer respects your privacy. This policy explains what we collect, why we collect it, and how you can control your data.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Data we collect', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '- Account: name, email, authentication identifiers (Firebase Auth).\n'
                    '- Profile: optional photo, city, bio (stored in Firebase).\n'
                    '- Usage: basic app interactions and diagnostics to improve stability.\n'
                    '- Location: only if you grant permission, to show nearby fields/events (not tracked in the background unless you enable it).',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('How we use data', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '- Provide core features (organize and join games).\n'
                    '- Personalize your experience (e.g., basic profile details).\n'
                    '- Communicate important updates and support responses.\n'
                    '- Keep the service secure (e.g., App Check, abuse prevention).',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Legal basis (GDPR)', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '- Contract: to deliver the app features you request.\n'
                    '- Legitimate interests: service improvement and security.\n'
                    '- Consent: optional features like notifications or analytics (if enabled in future).',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Third parties', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We use Google Firebase (Auth, Realtime Database, Storage, App Check) to operate the service. These providers process data on our behalf according to their terms.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Data retention', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We retain your data while your account is active. If you delete your account, we delete your profile and content within a reasonable period, subject to legal obligations and backups.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Your rights', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'You may request access, correction, deletion, or export of your data, and object to or restrict certain processing, as applicable. Use the in‑app Delete account option or contact support.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Contact', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Email: luisfccfigueiredo@gmail.com',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
