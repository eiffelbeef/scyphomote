import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/billing_provider.dart';

class PremiumScreen extends ConsumerWidget {
  static const routeName = '/premium';

  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final billingService = ref.read(billingServiceProvider);
    final isAvailable = billingService.isAvailable;

    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Premium')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPremium ? Icons.verified : Icons.lock_outline,
                size: 80,
                color: isPremium
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                isPremium ? 'You are Premium!' : 'Unlock Scyphomote Premium',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isPremium
                    ? 'Thank you for supporting the app. You now have full access to current and future premium features!'
                    : 'This feature is locked behind Scyphomote Premium. Purchasing premium grants you access to current and future premium features, forever.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (!isPremium) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Features:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Colors.green,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Home Screen Widget (control devices without opening the app)',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Colors.green,
                            ),
                            SizedBox(width: 8),
                            Expanded(child: Text('Support future development')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (!isPremium)
                if (isAvailable)
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(isPremiumProvider.notifier).buyPremium();
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Buy Now'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
