import 'package:flutter/material.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/marquee_text.dart';
import '../widgets/item_poster.dart';
import '../utils/playback_utils.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  final String title;
  final String parentId;
  final String? collectionType;
  final String? parentType;
  final bool isRoot;

  const ItemsScreen({
    super.key,
    required this.title,
    required this.parentId,
    this.collectionType,
    this.parentType,
    this.isRoot = false,
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

  @override
  void initState() {
    super.initState();
    _loadPreferences().then((_) => _fetchItems());
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
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);

      // Apply specialized sorting for Albums and Seasons
      String? sortBy = _sortBy;
      String? sortOrder = _sortOrder;

      if (widget.parentType == 'MusicAlbum') {
        sortBy = 'ParentIndexNumber,IndexNumber,SortName';
        sortOrder = 'Ascending';
      } else if (widget.parentType == 'Season') {
        sortBy = 'IndexNumber,SortName';
        sortOrder = 'Ascending';
      }

      final items = await apiService.getItems(
        user.userId,
        parentId: widget.parentId,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchTerm: _searchController.text.trim(),
        includeItemTypes:
            (widget.collectionType == 'music' && widget.isRoot && !_isSearching)
            ? _musicViewMode
            : null,
        recursive:
            _isSearching ||
            (widget.collectionType == 'music' &&
                widget.isRoot), // Search or root music view needs recursion
      );
      if (mounted) {
        setState(() {
          _items = items;
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

  String _getItemTitle(Map<String, dynamic> item) {
    final name = item['Name'] as String;
    final index = item['IndexNumber'] as int?;

    if (index != null &&
        (item['Type'] == 'Episode' || item['Type'] == 'Audio')) {
      final prefix = index.toString().padLeft(2, '0');
      return '$prefix. $name';
    }
    return name;
  }

  String? _getItemDuration(Map<String, dynamic> item) {
    final runTimeTicks = item['RunTimeTicks'] as int?;
    if (runTimeTicks == null) return null;
    final totalSeconds = runTimeTicks ~/ 10000000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final secondsStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final minutesStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesStr:$secondsStr';
    } else {
      return '$minutes:$secondsStr';
    }
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
              final item = items[index];
              final apiService = ref.read(apiServiceProvider);
              final imageUrl = apiService.getArtworkUrl(item['Id'], 'Primary');
              final isFolder = item['IsFolder'] ?? false;

              return SizedBox(
                width: 140,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  // Standard card shape for everyone (artists too)
                  child: InkWell(
                    onTap: () {
                      if (isFolder) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ItemsScreen(
                              title: item['Name'],
                              parentId: item['Id'],
                              collectionType: widget.collectionType,
                              parentType: item['Type'],
                            ),
                          ),
                        );
                      } else {
                        playItemOnRemote(context, ref, item);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ItemPoster(
                            imageUrl: imageUrl,
                            userData: item['UserData'],
                            placeholderIcon: widget.collectionType == 'music'
                                ? Icons.music_note
                                : Icons.movie,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MarqueeText(
                                text: _getItemTitle(item),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (item['ProductionYear'] != null &&
                                  (item['Type'] == 'Movie' ||
                                      item['Type'] == 'Series'))
                                Text(
                                  item['ProductionYear'].toString(),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
            },
          ),
        ),
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

    final artists = _items.where((i) => i['Type'] == 'MusicArtist').toList();
    final albums = _items.where((i) => i['Type'] == 'MusicAlbum').toList();
    final songs = _items.where((i) => i['Type'] == 'Audio').toList();
    final shows = _items.where((i) => i['Type'] == 'Series').toList();
    final seasons = _items.where((i) => i['Type'] == 'Season').toList();
    final episodes = _items.where((i) => i['Type'] == 'Episode').toList();
    final movies = _items.where((i) => i['Type'] == 'Movie').toList();

    // Fallback for others - only if NOT music mode
    final others = widget.collectionType == 'music'
        ? <Map<String, dynamic>>[]
        : _items
              .where(
                (i) => ![
                  'MusicArtist',
                  'MusicAlbum',
                  'Audio',
                  'Series',
                  'Season',
                  'Episode',
                  'Movie',
                ].contains(i['Type']),
              )
              .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildSection('Artists', artists),
        _buildSection('Albums', albums),
        _buildSection('Songs', songs),
        _buildSection('Shows', shows),
        _buildSection('Seasons', seasons),
        _buildSection('Episodes', episodes),
        _buildSection('Movies', movies),
        if (others.isNotEmpty) _buildSection('Other Results', others),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMusic = widget.collectionType == 'music';

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search...',
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
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchSubmitted = false;
                  _searchController.clear();
                });
                _fetchItems(); // Reset list
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                  _searchSubmitted = false;
                  _items = []; // Clear current list for clean start
                });
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort By',
              onSelected: (value) async {
                final storage = ref.read(storageServiceProvider);
                setState(() {
                  switch (value) {
                    case 'DateCreated,Descending':
                      _sortBy = 'DateCreated';
                      _sortOrder = 'Descending';
                      break;
                    case 'DateCreated,Ascending':
                      _sortBy = 'DateCreated';
                      _sortOrder = 'Ascending';
                      break;
                    case 'SortName,Ascending':
                      _sortBy = 'SortName';
                      _sortOrder = 'Ascending';
                      break;
                    case 'SortName,Descending':
                      _sortBy = 'SortName';
                      _sortOrder = 'Descending';
                      break;
                  }
                });
                await storage.saveBrowseSortBy(_sortBy!);
                await storage.saveBrowseSortOrder(_sortOrder!);
                _fetchItems();
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'DateCreated,Descending',
                  checked:
                      _sortBy == 'DateCreated' && _sortOrder == 'Descending',
                  child: Text(AppLocalizations.of(context)!.lastAdded),
                ),
                CheckedPopupMenuItem(
                  value: 'DateCreated,Ascending',
                  checked:
                      _sortBy == 'DateCreated' && _sortOrder == 'Ascending',
                  child: Text(AppLocalizations.of(context)!.oldestAdded),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'SortName,Ascending',
                  checked: _sortBy == 'SortName' && _sortOrder == 'Ascending',
                  child: Text(AppLocalizations.of(context)!.nameAZ),
                ),
                CheckedPopupMenuItem(
                  value: 'SortName,Descending',
                  checked: _sortBy == 'SortName' && _sortOrder == 'Descending',
                  child: Text(AppLocalizations.of(context)!.nameZA),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(AppLocalizations.of(context)!.errorMsg(_error!)))
          : _isSearching
          ? _buildSearchResults()
          : widget.parentType == 'MusicAlbum'
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text(AppLocalizations.of(context)!.play),
                        onPressed: () => playItemOnRemote(context, ref, {
                          'Id': widget.parentId,
                        }),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.shuffle),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final duration = _getItemDuration(item);

                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(_getItemTitle(item)),
                        trailing: duration != null
                            ? Text(
                                duration,
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            : null,
                        onTap: () => playItemOnRemote(context, ref, item),
                      );
                    },
                  ),
                ),
              ],
            )
          : widget.parentType == 'Season'
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                final apiService = ref.read(apiServiceProvider);
                final imageUrl = apiService.getArtworkUrl(
                  item['Id'],
                  'Primary',
                );
                final duration = _getItemDuration(item);

                return InkWell(
                  onTap: () => playItemOnRemote(context, ref, item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 68,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: ItemPoster(
                              imageUrl: imageUrl,
                              userData: item['UserData'],
                              placeholderIcon: Icons.movie,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _getItemTitle(item),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        if (duration != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            duration,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ref.watch(settingsProvider).libraryItemsPerRow,
                childAspectRatio: isMusic ? 1 : 2 / 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final apiService = ref.read(apiServiceProvider);
                final imageUrl = apiService.getArtworkUrl(
                  item['Id'],
                  'Primary',
                );
                final isFolder = item['IsFolder'] ?? false;

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      if (isFolder) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ItemsScreen(
                              title: item['Name'],
                              parentId: item['Id'],
                              collectionType: widget.collectionType,
                              parentType: item['Type'],
                            ),
                          ),
                        );
                      } else {
                        playItemOnRemote(context, ref, item);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ItemPoster(
                            imageUrl: imageUrl,
                            userData: item['UserData'],
                            placeholderIcon: isMusic
                                ? Icons.music_note
                                : Icons.movie,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MarqueeText(
                                text: _getItemTitle(item),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (item['ProductionYear'] != null &&
                                  (item['Type'] == 'Movie' ||
                                      item['Type'] == 'Series'))
                                Text(
                                  item['ProductionYear'].toString(),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
