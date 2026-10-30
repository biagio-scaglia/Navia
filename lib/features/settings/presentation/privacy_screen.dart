import 'package:flutter/material.dart';

import '../../../app/config/app_config.dart';
import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/privacy_policy.dart';
import '../../../core/utils/open_link.dart';
import '../../../core/widgets/navia_buttons.dart';
import '../../../core/widgets/navia_icon.dart';

/// Navia's privacy policy: a plain-language summary, then the full text.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const NaviaBackButton(),
        title: const Text(AppStrings.privacyPolicy),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                NaviaSpacing.lg,
                NaviaSpacing.sm,
                NaviaSpacing.lg,
                NaviaSpacing.xxl,
              ),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(NaviaSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const NaviaIconBadge(NaviaIcons.shield),
                            const SizedBox(width: NaviaSpacing.md),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  AppStrings.privacySummary,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: NaviaSpacing.md),
                        for (final point in PrivacyPolicy.summary)
                          _Bullet(point),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: NaviaSpacing.lg),
                Text(PrivacyPolicy.draftNotice, style: muted),
                const SizedBox(height: NaviaSpacing.xs),
                Text(
                  '${AppStrings.lastUpdated}: ${PrivacyPolicy.lastUpdated}',
                  style: muted,
                ),
                for (final section in PrivacyPolicy.sections) ...[
                  const SizedBox(height: NaviaSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final paragraph in section.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(top: NaviaSpacing.sm),
                      child: Text(paragraph, style: theme.textTheme.bodyLarge),
                    ),
                ],
                const SizedBox(height: NaviaSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        openExternalLink(context, AppConfig.privacyPolicyUrl),
                    icon: const NaviaIcon(NaviaIcons.externalLink, size: 20),
                    label: const Text(AppStrings.privacyPolicyOnline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: NaviaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: NaviaIcon(
              NaviaIcons.check,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: NaviaSpacing.md),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
