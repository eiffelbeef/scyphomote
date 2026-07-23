import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import 'package:scyphomote/providers/auth_provider.dart';
import '../providers/remote_providers.dart';
import '../providers/session_provider.dart';
import '../screens/item_details_screen.dart';
import '../screens/items_screen.dart';
import 'external_links_section.dart';
import 'drag_handle.dart';
import 'media_item_card.dart';
import '../utils/ui_utils.dart';

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
          final personItemsAsync = ref.watch(personItemsProvider(personId));
          final session = ref.watch(sessionProvider).selectedSession;
          final supportsMediaControl = session?.supportsMediaControl == true;

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
                                if (personItemsAsync.value != null && personItemsAsync.value!.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    l10n.appearsIn,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Builder(builder: (context) {
                                    final items = personItemsAsync.value!;
                                    final groupedItems = <String, List<Map<String, dynamic>>>{};
                                    for (final item in items) {
                                      final type = item['Type'] as String? ?? 'Unknown';
                                      (groupedItems[type] ??= []).add(item);
                                    }

                                    final sections = [
                                      (l10n.movies, 'Movie'),
                                      (l10n.shows, 'Series'),
                                      (l10n.seasons, 'Season'),
                                      (l10n.episodes, 'Episode'),
                                      (l10n.artists, 'MusicArtist'),
                                      (l10n.albums, 'MusicAlbum'),
                                      (l10n.songs, 'Audio'),
                                    ];

                                    final sectionWidgets = <Widget>[];
                                    for (final section in sections) {
                                      final title = section.$1;
                                      final type = section.$2;
                                      final sectionItems = groupedItems[type];
                                      if (sectionItems != null && sectionItems.isNotEmpty) {
                                        sectionWidgets.add(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                                child: Text(
                                                  title,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                height: 200,
                                                child: ListView.separated(
                                                  scrollDirection: Axis.horizontal,
                                                  itemCount: sectionItems.length,
                                                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                                                  itemBuilder: (context, index) {
                                                    final item = sectionItems[index];
                                                    final apiService = ref.read(apiServiceProvider);
                                                    final imageUrl = apiService.getItemImageUrl(item);
                                                    return MediaItemCard(
                                                      item: item,
                                                      imageUrl: imageUrl,
                                                      onTap: () {
                                                        if (supportsMediaControl) {
                                                          final isFolder = item['IsFolder'] == true;
                                                          final type = item['Type'];
                                                          if (type == 'Movie' || type == 'Series' || type == 'Season' || type == 'Episode' || type == 'MusicAlbum' || type == 'MusicArtist') {
                                                            Navigator.of(context).push(
                                                              MaterialPageRoute(
                                                                builder: (context) => ItemDetailsScreen(item: item),
                                                              ),
                                                            );
                                                          } else if (isFolder) {
                                                            Navigator.of(context).push(
                                                              MaterialPageRoute(
                                                                builder: (context) => ItemsScreen(
                                                                  title: UiUtils.getDisplayTitle(item),
                                                                  parentId: item['Id'],
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: sectionWidgets,
                                    );
                                  }),
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
