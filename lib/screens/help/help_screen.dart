import 'package:flutter/material.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:move_young/screens/legal/privacy_policy_screen.dart';
import 'package:move_young/screens/legal/terms_screen.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _version = '';
  static const String _faqUrl = 'https://example.com/help';
  static const String _supportEmail = 'luisfccfigueiredo@gmail.com';
  static const String _supportWhatsApp = '+31682081767';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {}
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('help_could_not_open_link'.tr())),
      );
    }
  }

  Future<void> _emailSupport({required String subject}) async {
    final body = Uri.encodeComponent(
        'Please describe your issue here.\n\nApp version: $_version');
    final uri = Uri.parse(
        'mailto:$_supportEmail?subject=${Uri.encodeComponent(subject)}&body=$body');
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('help_no_email_app'.tr())),
      );
    }
  }

  Future<void> _openWhatsApp() async {
    final phone = _supportWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent(
        'Hi, I need help with SmartPlayer (version: $_version)');
    final uri = Uri.parse('https://wa.me/$phone?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('help_could_not_open_link'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('help_title'.tr()),
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
            _buildSectionCard(
              child: Column(
                children: [
                  _buildLinkTile(
                    icon: Icons.question_mark_outlined,
                    title: 'help_faqs'.tr(),
                    onTap: () => _openUrl(_faqUrl),
                  ),
                  const Divider(height: 1, color: AppColors.lightgrey),
                  _buildLinkTile(
                    icon: Icons.mail_outline,
                    title: 'help_contact_support'.tr(),
                    subtitle: _supportEmail,
                    onTap: () => _emailSupport(subject: 'SmartPlayer Support'),
                  ),
                  const Divider(height: 1, color: AppColors.lightgrey),
                  _buildLinkTile(
                    icon: Icons.chat_outlined,
                    title: 'help_whatsapp'.tr(),
                    subtitle: _supportWhatsApp,
                    onTap: _openWhatsApp,
                    trailingChevron: true,
                  ),
                  const Divider(height: 1, color: AppColors.lightgrey),
                  // Removed report a problem per request
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              child: Column(
                children: [
                  _buildLinkTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'help_privacy'.tr(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    ),
                    trailingChevron: true,
                  ),
                  const Divider(height: 1, color: AppColors.lightgrey),
                  _buildLinkTile(
                    icon: Icons.article_outlined,
                    title: 'help_terms'.tr(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TermsScreen(),
                      ),
                    ),
                    trailingChevron: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                _version.isEmpty ? '' : '${'help_version'.tr()}: $_version',
                style: AppTextStyles.smallMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({String? title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.container),
        boxShadow: AppShadows.md,
      ),
      padding: AppPaddings.allBig,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool trailingChevron = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      subtitle:
          subtitle != null ? Text(subtitle, style: AppTextStyles.small) : null,
      trailing: trailingChevron ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
