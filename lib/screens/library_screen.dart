import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/marquee_text.dart';
import '../widgets/media_item_card.dart';
import '../widgets/remote_control_drawer.dart';
import '../utils/playback_utils.dart';
import '../utils/ui_utils.dart';
import 'items_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.librarySection),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.home_rounded), text: AppLocalizations.of(context)!.home),
              Tab(icon: const Icon(Icons.favorite_rounded), text: AppLocalizations.of(context)!.favorites),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HomeTab(),
            _FavoritesTab(),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
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
      
      final futures = [
        apiService.getViews(user.userId).then((views) {
          if (mounted) setState(() => _views = views);
        }),
        apiService.getResumeItems(user.userId).then((items) {
          if (mounted) setState(() => _resumeItems = items);
        }),
        apiService.getNextUpItems(user.userId).then((items) {
          if (mounted) setState(() => _nextUpItems = items);
        }),
      ];
      
      await Future.wait(futures);

      if (mounted) {
        setState(() {
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
      final mediaType = UiUtils.mapToMediaType(collectionType);

      if (mediaType == null) return false;

      return playableTypes.contains(mediaType);
    }).toList();
    bool isItemPlayable(Map<String, dynamic> item) {
      if (selectedSession == null || playableTypes.isEmpty) return true;
      final mediaType =
          item['MediaType'] as String? ??
          UiUtils.mapToMediaType(item['Type'] as String?);
      if (mediaType == null) return false;
      return playableTypes.contains(mediaType);
    }

    final filteredResumeItems = _resumeItems.where(isItemPlayable).toList();
    final filteredNextUpItems = _nextUpItems.where(isItemPlayable).toList();

    return Scaffold(
      
      body: Stack(
        children: [
          _isLoading && filteredViews.isEmpty && filteredResumeItems.isEmpty && filteredNextUpItems.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Text(AppLocalizations.of(context)!.errorMsg(_error!)),
                )
              : !_isLoading && filteredViews.isEmpty &&
                    filteredResumeItems.isEmpty &&
                    filteredNextUpItems.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 64,
                          color: Colors.grey,
                        ),
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
                    if (filteredResumeItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Resume',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
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
                            itemCount: filteredResumeItems.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final item = filteredResumeItems[index];
                              final apiService = ref.read(apiServiceProvider);
                              final imageUrl = apiService.getItemImageUrl(item);

                              return MediaItemCard(
                                item: item,
                                imageUrl: imageUrl,
                                onTap: () =>
                                    playItemOnRemote(context, ref, item),
                              );
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                    if (filteredNextUpItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Next Up',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
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
                            itemCount: filteredNextUpItems.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final item = filteredNextUpItems[index];
                              final apiService = ref.read(apiServiceProvider);
                              final imageUrl = apiService.getItemImageUrl(item);

                              return MediaItemCard(
                                item: item,
                                imageUrl: imageUrl,
                                onTap: () =>
                                    playItemOnRemote(context, ref, item),
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
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
                          final imageUrl = apiService.getItemImageUrl(view);

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
                                    errorWidget: (context, url, error) =>
                                        Container(
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
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: UiUtils.getBottomPaddingForDrawer(context, ref),
                      ),
                    ),
                  ],
                ),
          const RemoteControlDrawer(),
        ],
      ),
    );
  }

}

class _FavoritesTab extends ConsumerStatefulWidget {
  const _FavoritesTab();

  @override
  ConsumerState<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends ConsumerState<_FavoritesTab> {
  List<Map<String, dynamic>> _favoriteItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;
    try {
      final apiService = ref.read(apiServiceProvider);
      final types = [
        'Movie',
        'Series',
        'Season',
        'Episode',
        'Video',
        'MusicVideo',
        'BoxSet',
        'Playlist',
        'MusicAlbum',
        'Audio',
        'LiveTVChannel',
      ];
      final futures = types.map((type) async {
        try {
          final result = await apiService.getFavoriteItems(user.userId, type);
          final items = (result['Items'] as List).map((e) => e as Map<String, dynamic>).toList();
          if (mounted && items.isNotEmpty) {
            setState(() {
              _favoriteItems = [..._favoriteItems, ...items];
            });
          }
        } catch (e) {
          debugPrint('Error fetching favorite $type: $e');
        }
      });
      
      await Future.wait(futures);

      if (mounted) {
        setState(() {
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


  bool _isItemPlayable(Map<String, dynamic> item) {
    final sessionState = ref.watch(sessionProvider);
    final selectedSession = sessionState.selectedSession;
    final playableTypes =
        selectedSession?.playableMediaTypes
            .map((e) => e.toLowerCase())
            .toList() ??
        [];
    if (selectedSession == null || playableTypes.isEmpty) return true;

    var mediaType = item['MediaType'] as String?;
    if (mediaType == null ||
        mediaType.isEmpty ||
        mediaType.toLowerCase() == 'unknown') {
      mediaType = UiUtils.mapToMediaType(item['Type'] as String?);
    }

    if (mediaType == null) return false;
    return playableTypes.contains(mediaType.toLowerCase());
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ref.watch(settingsProvider).libraryItemsPerRow,
              childAspectRatio: UiUtils.getItemAspectRatio(items.firstOrNull),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              final apiService = ref.read(apiServiceProvider);
              final imageUrl = apiService.getItemImageUrl(item);
              final isFolder = item['IsFolder'] ?? false;

              return MediaItemCard(
                item: item,
                imageUrl: imageUrl,
                onTap: () {
                  if (isFolder) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ItemsScreen(
                          title: item['Name'],
                          parentId: item['Id'],
                          collectionType: null,
                          parentType: item['Type'],
                        ),
                      ),
                    );
                  } else {
                    playItemOnRemote(context, ref, item);
                  }
                },
              );
            }, childCount: items.length),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _favoriteItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(AppLocalizations.of(context)!.errorMsg(_error!)),
      );
    }

    final filteredFavoriteItems = _favoriteItems.where(_isItemPlayable).toList();

    if (filteredFavoriteItems.isEmpty) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No Favorites',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Mark items as favorite to see them here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final movies = filteredFavoriteItems.where((i) => i['Type'] == 'Movie').toList();
    final shows = filteredFavoriteItems.where((i) => i['Type'] == 'Series').toList();
    final seasons = filteredFavoriteItems.where((i) => i['Type'] == 'Season').toList();
    final episodes = filteredFavoriteItems.where((i) => i['Type'] == 'Episode').toList();
    final albums = filteredFavoriteItems.where((i) => i['Type'] == 'MusicAlbum').toList();
    final songs = filteredFavoriteItems.where((i) => i['Type'] == 'Audio').toList();
    final musicVideos = filteredFavoriteItems.where((i) => i['Type'] == 'MusicVideo').toList();
    final videos = filteredFavoriteItems.where((i) => i['Type'] == 'Video').toList();
    
    final handledTypes = ['Movie', 'Series', 'Season', 'Episode', 'MusicAlbum', 'Audio', 'MusicVideo', 'Video'];
    final others = filteredFavoriteItems.where((i) => !handledTypes.contains(i['Type'])).toList();

    return CustomScrollView(
      slivers: [
        _buildSection('Movies', movies),
        _buildSection('Shows', shows),
        _buildSection('Seasons', seasons),
        _buildSection('Episodes', episodes),
        _buildSection('Albums', albums),
        _buildSection('Songs', songs),
        _buildSection('Music Videos', musicVideos),
        _buildSection('Videos', videos),
        _buildSection('Other', others),
        SliverToBoxAdapter(
          child: SizedBox(
            height: UiUtils.getBottomPaddingForDrawer(context, ref),
          ),
        ),
      ],
    );
  }
}
