import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../providers/remote_providers.dart';
import 'external_links_section.dart';
import 'drag_handle.dart';

void showPersonDetailSheet(BuildContext context, String personId, String personName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, child) {
          final detailsAsync = ref.watch(itemDetailsProvider(personId));

          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              final l10n = AppLocalizations.of(context)!;
              return detailsAsync.when(
                data: (details) {
                  final name = details?['Name'] as String? ?? personName;
                  final overview = details?['Overview'] as String?;
                  final externalUrls =
                      (details?['ExternalUrls'] as List?)?.cast<Map<String, dynamic>>() ?? [];

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      const DragHandle(),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (overview != null && overview.isNotEmpty)
                                Text(
                                  overview,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                )
                              else
                                Text(
                                  l10n.noOverviewAvailable,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                              if (externalUrls.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text(
                                  l10n.externalLinks,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                ExternalLinksSection(
                                  externalUrls: externalUrls,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(err.toString()),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
