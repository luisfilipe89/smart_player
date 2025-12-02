import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/widgets/app_back_button.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('help_terms'.tr()),
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
                  Text('help_terms'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'terms_content'.tr(),
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
