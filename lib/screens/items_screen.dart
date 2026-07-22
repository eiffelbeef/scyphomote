import 'package:flutter/material.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/remote_control_drawer.dart';
import '../utils/playback_utils.dart';
import '../utils/ui_utils.dart';
import '../constants.dart';
import '../widgets/music_track_tile.dart';
import '../widgets/item_card.dart';
import '../widgets/episode_row.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  final String title;
  final String? parentId;
  final String? collectionType;
  final String? parentType;
  final bool isRoot;
  final bool startInSearchMode;

  const ItemsScreen({
    super.key,
    required this.title,
    this.parentId,
    this.collectionType,
    this.parentType,
    this.isRoot = false,
    this.startInSearchMode = false,
  });

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  // Sort & Search State
  String? _sortBy = 'DateCreated';
  String? _sortOrder = 'Descending';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  bool _searchSubmitted = false;

  // Pagination State
  final ScrollController _scrollController = ScrollController();
  int _startIndex = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.startInSearchMode) {
      _isSearching = true;
    }
    _loadPreferences().then((_) => _fetchItems());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchMoreItems();
    }
  }

  Future<void> _loadPreferences() async {
    final storage = ref.read(storageServiceProvider);
    final savedSortBy = await storage.getBrowseSortBy();
    final savedSortOrder = await storage.getBrowseSortOrder();
    final savedMusicView = await storage.getMusicViewMode();

    if (mounted) {
      if (widget.collectionType == 'music' && widget.isRoot) {
        _musicViewMode = savedMusicView ?? 'MusicArtist';
        _tabController = TabController(
          length: 2,
          vsync: this,
          initialIndex: _musicViewMode == 'MusicArtist' ? 0 : 1,
        );
        _tabController!.addListener(_handleTabChange);
      }

      setState(() {
        if (savedSortBy != null) _sortBy = savedSortBy;
        if (savedSortOrder != null) _sortOrder = savedSortOrder;
      });
    }
  }

  void _handleTabChange() async {
    if (_tabController == null || !_tabController!.indexIsChanging) return;

    final newMode = _tabController!.index == 0 ? 'MusicArtist' : 'MusicAlbum';
    if (newMode == _musicViewMode) return;

    final storage = ref.read(storageServiceProvider);
    setState(() {
      _musicViewMode = newMode;
    });
    await storage.saveMusicViewMode(newMode);
    _fetchItems();
  }

  TabController? _tabController;
  String _musicViewMode = 'MusicArtist';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchItems({bool loadMore = false}) async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    if (!mounted) return;

    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        _startIndex = 0;
        _hasMore = true;
        _items.clear();
      });
    }

    if (widget.parentId == null && _searchController.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _items = [];
        });
      }
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);

      String? sortBy = _sortBy;
      String? sortOrder = _sortOrder;

      if (widget.parentType == 'MusicAlbum') {
        sortBy = 'ParentIndexNumber,IndexNumber,SortName';
        sortOrder = 'Ascending';
      } else if (widget.parentType == 'Season') {
        sortBy = 'IndexNumber,SortName';
        sortOrder = 'Ascending';
      }

      String? includeItemTypes;
      if (widget.collectionType == 'music' && widget.isRoot && !_isSearching) {
        includeItemTypes = _musicViewMode;
      } else if (widget.isRoot && widget.collectionType != 'music') {
        includeItemTypes = switch (widget.collectionType) {
          'tvshows' => 'Series',
          'movies' => 'Movie',
          'boxsets' => 'BoxSet',
          _ => 'Movie,Series,MusicArtist,MusicAlbum,BoxSet,Video,Audio',
        };

        if (_isSearching && includeItemTypes.contains('Series')) {
          includeItemTypes += ',Episode';
        }
      }

      final data = await apiService.getItems(
        user.userId,
        parentId: widget.parentId,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchTerm: _searchController.text.trim(),
        includeItemTypes: includeItemTypes,
        excludeItemTypes: (widget.isRoot && widget.collectionType != 'music') ? 'Folder' : null,
        recursive: _isSearching || widget.isRoot,
        startIndex: _startIndex,
        limit: AppConstants.paginationLimit,
      );

      final newItems = (data['Items'] as List).map((e) => e as Map<String, dynamic>).toList();
      final totalRecordCount = data['TotalRecordCount'] as int? ?? 0;

      if (mounted) {
        setState(() {
          if (loadMore) {
            _items.addAll(newItems);
            _isLoadingMore = false;
          } else {
            _items = newItems;
            _isLoading = false;
          }

          _startIndex += newItems.length;
          _hasMore = _startIndex < totalRecordCount;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (loadMore) {
            _isLoadingMore = false;
          } else {
            _error = e.toString();
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<void> _fetchMoreItems() async {
    if (_isLoadingMore || !_hasMore) return;
    await _fetchItems(loadMore: true);
  }



  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(
          height: 200, // Adjusted height for horizontal list items
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 140,
                child: ItemCard(
                  item: items[index],
                  apiService: ref.read(apiServiceProvider),
                  isMusic: widget.collectionType == 'music',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPadding(double extraSpace) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        SizedBox(height: UiUtils.getBottomPaddingForDrawer(context, ref) + extraSpace),
      ],
    );
  }



  Widget _buildSearchResults() {
    if (!_searchSubmitted) {
      return Center(child: Text(AppLocalizations.of(context)!.typeToSearch));
    }

    if (_items.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noResultsFound));
    }

    final groupedItems = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final type = item['Type'] as String? ?? 'Unknown';
      (groupedItems[type] ??= []).add(item);
    }

    final sections = [
      ('Artists', 'MusicArtist'),
      ('Albums', 'MusicAlbum'),
      ('Songs', 'Audio'),
      ('Shows', 'Series'),
      ('Seasons', 'Season'),
      ('Episodes', 'Episode'),
      ('Movies', 'Movie'),
    ];

    final children = <Widget>[];
    final processedTypes = <String>{};

    for (final (title, type) in sections) {
      processedTypes.add(type);
      final items = groupedItems[type] ?? [];
      if (items.isNotEmpty) children.add(_buildSection(title, items));
    }

    if (widget.collectionType != 'music') {
      final others = groupedItems.entries
          .where((e) => !processedTypes.contains(e.key))
          .expand((e) => e.value)
          .toList();
      if (others.isNotEmpty) children.add(_buildSection('Other Results', others));
    }

    children.add(_buildBottomPadding(24));

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMusic = widget.collectionType == 'music';

    Widget buildBodyContent() {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return Center(child: Text(AppLocalizations.of(context)!.errorMsg(_error!)));
      }
      if (_isSearching) {
        return _buildSearchResults();
      }

      switch (widget.parentType) {
        case 'MusicAlbum':
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16.0,
                  runSpacing: 16.0,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(AppLocalizations.of(context)!.play),
                      onPressed: () => playItemOnRemote(context, ref, {
                        'Id': widget.parentId,
                      }),
                    ),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.shuffle_rounded),
                      label: Text(AppLocalizations.of(context)!.shuffle),
                      onPressed: () => playItemOnRemote(context, ref, {
                        'Id': widget.parentId,
                      }, playCommand: 'PlayShuffle'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  itemCount: _items.length + 1,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == _items.length) {
                      return _buildBottomPadding(8);
                    }
                    final item = _items[index];
                    return MusicTrackTile(item: item);
                  },
                ),
              ),
            ],
          );
        case 'Season':
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            controller: _scrollController,
            itemCount: _items.length + 1,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return _buildBottomPadding(8);
              }
              final item = _items[index];
              return EpisodeRow(
                item: item,
                apiService: ref.read(apiServiceProvider),
              );
            },
          );
        default:
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: ref.watch(settingsProvider).libraryItemsPerRow,
                    childAspectRatio: UiUtils.getItemAspectRatio(_items.firstOrNull),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return ItemCard(
                        item: _items[index],
                        apiService: ref.read(apiServiceProvider),
                        collectionType: widget.collectionType,
                        isMusic: isMusic,
                      );
                    },
                    childCount: _items.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildBottomPadding(16),
              ),
            ],
          );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.typeToSearch,
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  setState(() {
                    _searchSubmitted = true;
                  });
                  _fetchItems();
                },
              )
            : Text(widget.title),
        bottom:
            (isMusic &&
                widget.isRoot &&
                !_isSearching &&
                _tabController != null)
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Artists', icon: Icon(Icons.person_outline)),
                  Tab(text: 'Albums', icon: Icon(Icons.album_outlined)),
                ],
              )
            : null,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                if (widget.startInSearchMode) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _isSearching = false;
                    _searchSubmitted = false;
                    _searchController.clear();
                  });
                  _fetchItems(); // Reset list
                }
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                  _searchSubmitted = false;
                  _items = []; // Clear current list for clean start
                });
              },
            ),
            PopupMenuButton<(String, String)>(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort By',
              onSelected: (value) async {
                final storage = ref.read(storageServiceProvider);
                setState(() {
                  final (newSortBy, newSortOrder) = value;
                  _sortBy = newSortBy;
                  _sortOrder = newSortOrder;
                });
                await storage.saveBrowseSortBy(_sortBy!);
                await storage.saveBrowseSortOrder(_sortOrder!);
                _fetchItems();
              },
              itemBuilder: (context) {
                final l10n = AppLocalizations.of(context)!;
                CheckedPopupMenuItem<(String, String)> buildSortItem(
                    String by, String order, String text) {
                  return CheckedPopupMenuItem(
                    value: (by, order),
                    checked: _sortBy == by && _sortOrder == order,
                    child: Text(text),
                  );
                }

                return [
                  buildSortItem('DateCreated', 'Descending', l10n.lastAdded),
                  buildSortItem('DateCreated', 'Ascending', l10n.oldestAdded),
                  const PopupMenuDivider(),
                  buildSortItem('SortName', 'Ascending', l10n.nameAZ),
                  buildSortItem('SortName', 'Descending', l10n.nameZA),
                ];
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          buildBodyContent(),
          const RemoteControlDrawer(),
        ],
      ),
    );
  }
}
