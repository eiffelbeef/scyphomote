import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/billing_provider.dart';
import 'package:scyphomote/l10n/app_localizations.dart';

class PremiumScreen extends ConsumerWidget {
  static const routeName = '/premium';
  const PremiumScreen({super.key});

  static const _supportTiers = [
    'scyphomote_support_tier1',
    'scyphomote_support_tier2',
    'scyphomote_support_tier3',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final billingService = ref.read(billingServiceProvider);
    final isAvailable = billingService.isAvailable;
    final history = ref.watch(supportHistoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.unlockPremium)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _PremiumHeader(isPremium: isPremium, l10n: l10n, theme: theme),
            if (!isPremium) ...[
              const SizedBox(height: 24),
              _PremiumFeatures(l10n: l10n, theme: theme),
              const SizedBox(height: 32),
              if (isAvailable)
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(isPremiumProvider.notifier).buyPremium(),
                  icon: const Icon(Icons.shopping_cart),
                  label: Text(l10n.buyNow),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
            ],

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

            if (history.isNotEmpty) ...[
              const SizedBox(height: 32),
              _SupportThankYou(l10n: l10n, theme: theme),
              const SizedBox(height: 16),
              _SupportHistory(history: history, l10n: l10n, theme: theme),
            ],

            if (isAvailable) ...[
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () =>
                    ref.read(isPremiumProvider.notifier).restorePurchases(),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.restorePurchases),
              ),
            ],
            const SizedBox(height: 16),
          ],
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
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PremiumHeader({
    required this.isPremium,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(
        isPremium ? Icons.verified : Icons.lock_outline,
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
    ],
  );
}

class _PremiumFeatures extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PremiumFeatures({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) => Card(
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
          _featureRow(l10n.supportFutureDevelopment),
        ],
      ),
    ),
  );

  Widget _featureRow(String text) => Row(
    children: [
      const Icon(Icons.check_circle, size: 20, color: Colors.green),
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
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: theme.colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Icon(Icons.favorite, size: 40, color: Colors.red),
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
    return Column(
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
            leading: const Icon(Icons.volunteer_activism, size: 20),
            title: Text(tierName),
            trailing: Text(formatted, style: theme.textTheme.bodySmall),
          );
        }),
      ],
    );
  }

  String _tierName(AppLocalizations l10n, String productId) =>
      switch (productId) {
        'scyphomote_support_tier1' => l10n.supportTier1,
        'scyphomote_support_tier2' => l10n.supportTier2,
        _ => l10n.supportTier3,
      };
}
