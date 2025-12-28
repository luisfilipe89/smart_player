import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/widgets/app_back_button.dart';

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
                    'privacy_last_updated'.tr(),
                    style: AppTextStyles.smallMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'privacy_intro'.tr(),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('privacy_data_collect_title'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'privacy_data_collect_content'.tr(),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('privacy_data_use_title'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'privacy_data_use_content'.tr(),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('privacy_legal_basis_title'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'privacy_legal_basis_content'.tr(),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('privacy_third_parties_title'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'privacy_third_parties_content'.tr(),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('privacy_retention_title'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'privacy_retention_content'.tr(),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('privacy_rights_title'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'privacy_rights_content'.tr(),
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
