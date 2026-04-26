import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/marquee_text.dart';
import '../widgets/media_item_card.dart';
import '../utils/playback_utils.dart';
import 'items_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<Map<String, dynamic>> _views = [];
  List<Map<String, dynamic>> _resumeItems = [];
  List<Map<String, dynamic>> _nextUpItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchViews();
  }

  Future<void> _fetchViews() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      final views = await apiService.getViews(user.userId);
      final resumeItems = await apiService.getResumeItems(user.userId);
      final nextUpItems = await apiService.getNextUpItems(user.userId);

      if (mounted) {
        setState(() {
          _views = views;
          _resumeItems = resumeItems;
          _nextUpItems = nextUpItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context)!.notAuthenticated),
        ),
      );
    }

    final sessionState = ref.watch(sessionProvider);
    final selectedSession = sessionState.selectedSession;
    final playableTypes = selectedSession?.playableMediaTypes ?? [];

    final filteredViews = _views.where((view) {
      // If we don't have a session or playable types, show all (fallback)
      if (selectedSession == null || playableTypes.isEmpty) return true;

      final collectionType = view['CollectionType'] as String?;
      final mediaType = _mapCollectionTypeToMediaType(collectionType);

      // User requested to ignore unknown
      if (mediaType == null) return false;

      return playableTypes.contains(mediaType);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.librarySection)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(AppLocalizations.of(context)!.errorMsg(_error!)))
          : filteredViews.isEmpty &&
                _resumeItems.isEmpty &&
                _nextUpItems.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No supported libraries',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This client does not report support for any of your available library types.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                if (_resumeItems.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Resume',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _resumeItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = _resumeItems[index];
                          final apiService = ref.read(apiServiceProvider);
                          final imageUrl = apiService.getArtworkUrl(
                            item['Id'],
                            'Primary',
                          );

                          return MediaItemCard(
                            item: item,
                            imageUrl: imageUrl,
                            onTap: () => playItemOnRemote(context, ref, item),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                if (_nextUpItems.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'Next Up',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _nextUpItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = _nextUpItems[index];
                          final apiService = ref.read(apiServiceProvider);
                          final imageUrl = apiService.getArtworkUrl(
                            item['Id'],
                            'Primary',
                          );

                          return MediaItemCard(
                            item: item,
                            imageUrl: imageUrl,
                            onTap: () => playItemOnRemote(context, ref, item),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Libraries',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ref
                          .watch(settingsProvider)
                          .libraryItemsPerRow,
                      childAspectRatio: 16 / 9,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final view = filteredViews[index];
                      final apiService = ref.read(apiServiceProvider);
                      final imageUrl = apiService.getArtworkUrl(
                        view['Id'],
                        'Primary',
                      );

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ItemsScreen(
                                  title: view['Name'],
                                  parentId: view['Id'],
                                  collectionType: view['CollectionType'],
                                  parentType: view['CollectionType'],
                                  isRoot: true,
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(Icons.folder_rounded),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(Icons.folder_off),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black87,
                                    ],
                                    stops: [0.6, 1.0],
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: MarqueeText(
                                    text: view['Name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: filteredViews.length),
                  ),
                ),
              ],
            ),
    );
  }

  String? _mapCollectionTypeToMediaType(String? collectionType) {
    switch (collectionType?.toLowerCase()) {
      case 'movies':
      case 'tvshows':
      case 'musicvideos':
      case 'homevideos':
      case 'boxsets':
      case 'trailers':
        return 'Video';
      case 'music':
        return 'Audio';
      case 'books':
        return 'Book';
      case 'photos':
        return 'Photo';
      default:
        return null; // Unknown
    }
  }
}
