import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../providers/billing_provider.dart';
import '../utils/ui_utils.dart';
import 'package:scyphomote/l10n/app_localizations.dart';

class PremiumScreen extends ConsumerWidget {
  static const routeName = '/premium';
  const PremiumScreen({super.key});

  static const _supportTiers = [
    'scyphomote_support_tier1',
    'scyphomote_support_tier2',
    'scyphomote_support_tier3',
  ];

  void _showLicenseDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isActivating = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.key_rounded),
                  const SizedBox(width: 8),
                  Text(l10n.enterLicenseKey),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pasteLicenseKey,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: l10n.licenseKeyHint,
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                setState(() {
                                  controller.clear();
                                  errorMessage = null;
                                });
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.content_paste_rounded, size: 20),
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null) {
                                setState(() {
                                  controller.text = data!.text!.trim();
                                  errorMessage = null;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setState(() => errorMessage = null);
                      }
                    },
                    maxLines: 2,
                    minLines: 1,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isActivating ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: isActivating
                      ? null
                      : () async {
                          final key = controller.text.trim();
                          if (key.isEmpty) return;

                          setState(() {
                            isActivating = true;
                            errorMessage = null;
                          });

                          final success = await ref
                              .read(isPremiumProvider.notifier)
                              .activateLicense(key);

                          if (context.mounted) {
                            if (success) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.licenseKeyActivated),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              setState(() {
                                isActivating = false;
                                errorMessage = l10n.licenseKeyInvalid;
                              });
                            }
                          }
                        },
                  child: isActivating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.activate),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRemoveLicense(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removeLicense),
        content: Text(l10n.removeLicenseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(isPremiumProvider.notifier).removeLicense();
            },
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final licensedId = ref.watch(licensedIdentifierProvider);
    final billingService = ref.read(billingServiceProvider);
    final isAvailable = billingService.isAvailable;
    final history = ref.watch(supportHistoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.unlockPremium)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PremiumHeader(
                isPremium: isPremium,
                licensedIdentifier: isAvailable ? null : licensedId,
                onRemoveLicense: () => _confirmRemoveLicense(context, ref),
                l10n: l10n,
                theme: theme,
              ),
            if (!isPremium) ...[
              const SizedBox(height: 24),
              _PremiumFeatures(l10n: l10n, theme: theme),
              const SizedBox(height: 32),
              if (isAvailable) ...[
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(isPremiumProvider.notifier).buyPremium(),
                  icon: const Icon(Icons.shopping_cart_rounded),
                  label: Text(l10n.buyNow),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ] else ...[
                _GitHubSponsorsCard(
                  onSponsorPressed: () => UiUtils.launchUrl(AppConstants.githubSponsorsUrl),
                  onRetrieveLicensePressed: () => UiUtils.launchUrl(AppConstants.licensePortalUrl),
                  onEnterLicensePressed: () => _showLicenseDialog(context, ref),
                  l10n: l10n,
                  theme: theme,
                ),
              ],
            ],

            if (isAvailable) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                l10n.supportAppTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.supportAppDescription,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, id) in _supportTiers.indexed)
                    OutlinedButton(
                      onPressed: isAvailable
                          ? () => ref
                                .read(supportHistoryProvider.notifier)
                                .buySupport(id)
                          : null,
                      child: Text(_tierLabel(l10n, i)),
                    ),
                ],
              ),
            ],

            if (history.isNotEmpty) ...[
              const SizedBox(height: 32),
              _SupportThankYou(l10n: l10n, theme: theme),
              const SizedBox(height: 16),
              _SupportHistory(history: history, l10n: l10n, theme: theme),
            ],
          ],
        ),
      ),
    ),
  );
  }

  String _tierLabel(AppLocalizations l10n, int index) => switch (index) {
    0 => l10n.supportTier1,
    1 => l10n.supportTier2,
    _ => l10n.supportTier3,
  };
}

class _PremiumHeader extends StatelessWidget {
  final bool isPremium;
  final String? licensedIdentifier;
  final VoidCallback onRemoveLicense;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PremiumHeader({
    required this.isPremium,
    this.licensedIdentifier,
    required this.onRemoveLicense,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(
        isPremium ? Icons.verified_rounded : Icons.lock_outline_rounded,
        size: 80,
        color: isPremium ? Colors.green : theme.colorScheme.primary,
      ),
      const SizedBox(height: 24),
      Text(
        isPremium ? l10n.youArePremium : l10n.unlockScyphomotePremium,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      Text(
        isPremium ? l10n.premiumThankYou : l10n.premiumDescription,
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      if (isPremium && licensedIdentifier != null) ...[
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                const Icon(Icons.key_rounded, size: 20, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.licenseActive(licensedIdentifier!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.removeLicense,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: onRemoveLicense,
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class _GitHubSponsorsCard extends StatelessWidget {
  final VoidCallback onSponsorPressed;
  final VoidCallback onRetrieveLicensePressed;
  final VoidCallback onEnterLicensePressed;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _GitHubSponsorsCard({
    required this.onSponsorPressed,
    required this.onRetrieveLicensePressed,
    required this.onEnterLicensePressed,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Icon(Icons.favorite_rounded, size: 44, color: Colors.pinkAccent),
              const SizedBox(height: 12),
              Text(
                l10n.sponsorOnGitHub,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.sponsorOnGitHubDesc,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: onSponsorPressed,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(l10n.sponsorOnGitHub),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onRetrieveLicensePressed,
                      icon: const Icon(Icons.vpn_key_rounded),
                      label: Text(l10n.retrieveLicenseKey),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onEnterLicensePressed,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: Text(l10n.enterLicenseKey),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumFeatures extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PremiumFeatures({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.premiumFeatures,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _featureRow(l10n.premiumFeatureWidget),
          const SizedBox(height: 8),
          _featureRow(l10n.premiumFeatureBackground),
          const SizedBox(height: 8),
          _featureRow(l10n.supportFutureDevelopment),
        ],
      ),
    ),
  ),
);

  Widget _featureRow(String text) => Row(
    children: [
      const Icon(Icons.check_circle_rounded, size: 20, color: Colors.green),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

class _SupportThankYou extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _SupportThankYou({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.favorite_rounded, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              l10n.supportThankYou,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.supportContactMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Clipboard.setData(
                  const ClipboardData(text: 'eiffelbeef@proton.me'),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.addressCopied('eiffelbeef@proton.me')),
                  ),
                );
              },
              child: Text(
                'eiffelbeef@proton.me',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SupportHistory extends StatelessWidget {
  final List<String> history;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _SupportHistory({
    required this.history,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.supportHistory,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 8),
        ...history.reversed.map((raw) {
          final entry = jsonDecode(raw) as Map<String, dynamic>;
          final product = entry['product'] as String;
          final date = DateTime.parse(entry['date'] as String);
          final tierName = _tierName(l10n, product);
          final formatted = DateFormat.yMMMd().format(date);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.volunteer_activism_rounded, size: 20),
            title: Text(tierName),
            trailing: Text(formatted, style: theme.textTheme.bodySmall),
          );
        }),
      ],
    ),
  );
}

  String _tierName(AppLocalizations l10n, String productId) =>
      switch (productId) {
        'scyphomote_support_tier1' => l10n.supportTier1,
        'scyphomote_support_tier2' => l10n.supportTier2,
        _ => l10n.supportTier3,
      };
}
