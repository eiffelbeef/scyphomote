import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';

class AboutScreen extends StatelessWidget {
  static const routeName = '/about';
  const AboutScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _copyToClipboard(BuildContext context, String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label address copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Image.asset('assets/scyphomote.png', width: 120, height: 120),
            const SizedBox(height: 16),
            Text(
              AppConstants.appName,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Text('A Remote for Jellyfin'),
            const Text('Version ${AppConstants.appVersion}'),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Author',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'EiffelBeef',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _launchUrl(AppConstants.githubUrl),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.code_rounded, size: 20),
                    const SizedBox(width: 8),
                    const Text('GitHub Repository'),
                  ],
                ),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                'Support the Developer',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () =>
                    _launchUrl('https://liberapay.com/EiffelBeef/donate'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text('Donate using Liberapay'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SupportItem(
                context: context,
                label: 'BTC',
                address: '1CoFc1bY5AHLP6Noe1zmqnJnp7ZWBxyo79',
                onCopy: () => _copyToClipboard(
                  context,
                  'BTC',
                  '1CoFc1bY5AHLP6Noe1zmqnJnp7ZWBxyo79',
                ),
              ),
              _SupportItem(
                context: context,
                label: 'ETH',
                address: '0xf68f568e21a15934e0e9a6949288c3ca009140ba',
                onCopy: () => _copyToClipboard(
                  context,
                  'ETH',
                  '0xf68f568e21a15934e0e9a6949288c3ca009140ba',
                ),
              ),
              _SupportItem(
                context: context,
                label: 'XMR',
                address:
                    '88wjCuhHX3oNhVpEdYeUx3LvrkdTvcTHx7v7L5fQpjCg7QiAReJUVR4LPase5Byj2UhdVdLtvysJaXTFKq2EnuvuLjvQMGL',
                onCopy: () => _copyToClipboard(
                  context,
                  'Monero (XMR)',
                  '88wjCuhHX3oNhVpEdYeUx3LvrkdTvcTHx7v7L5fQpjCg7QiAReJUVR4LPase5Byj2UhdVdLtvysJaXTFKq2EnuvuLjvQMGL',
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Licensed under GNU AGPLv3',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 64),
            Text(
              '© 2026 EiffelBeef',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportItem extends StatelessWidget {
  final BuildContext context;
  final String label;
  final String address;
  final VoidCallback onCopy;

  const _SupportItem({
    required this.context,
    required this.label,
    required this.address,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Card(
        elevation: 0,
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: ListTile(
          dense: true,
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: onCopy,
            tooltip: 'Copy address',
          ),
        ),
      ),
    );
  }
}
