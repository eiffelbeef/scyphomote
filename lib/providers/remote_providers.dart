import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../utils/logger.dart';

final itemDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, itemId) async {
      final authState = ref.watch(authProvider);
      final user = authState.currentUser;
      final apiService = ref.read(apiServiceProvider);

      if (user == null) return null;

      try {
        return await apiService.getItemDetails(user.userId, itemId);
      } catch (e) {
        logError('Failed to fetch item details: $e');
        return null;
      }
    });

final itemFavoriteProvider =
    FutureProvider.family<bool, String>((ref, itemId) async {
      try {
        final itemData = await ref.watch(itemDetailsProvider(itemId).future);
        return itemData?['UserData']?['IsFavorite'] ?? false;
      } catch (e) {
        return false;
      }
    });

final itemPlayedProvider =
    FutureProvider.family<bool, String>((ref, itemId) async {
      try {
        final itemData = await ref.watch(itemDetailsProvider(itemId).future);
        return itemData?['UserData']?['Played'] ?? false;
      } catch (e) {
        return false;
      }
    });

final playbackInfoProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, itemId) async {
      final authState = ref.watch(authProvider);
      final user = authState.currentUser;
      final apiService = ref.read(apiServiceProvider);

      if (user == null) return null;

      try {
        return await apiService.getPlaybackInfo(user.userId, itemId);
      } catch (e) {
        logError('Failed to fetch playback info: $e');
        return null;
      }
    });

final lyricsProvider =
    FutureProvider.family<
      Map<String, dynamic>?,
      ({String itemId, bool hasLyrics})
    >((ref, params) async {
      if (!params.hasLyrics) return null;

      final authState = ref.watch(authProvider);
      final user = authState.currentUser;
      final apiService = ref.read(apiServiceProvider);

      if (user == null) return null;

      try {
        return await apiService.getLyrics(params.itemId);
      } catch (e) {
        logError('Failed to fetch lyrics: $e');
        return null;
      }
    });

final itemChildrenProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ({String itemId, String type})>((ref, params) async {
      final authState = ref.watch(authProvider);
      final user = authState.currentUser;
      final apiService = ref.read(apiServiceProvider);

      if (user == null) return [];

      try {
        final type = params.type;
        if (type != 'Series' && type != 'Season' && type != 'MusicArtist' && type != 'MusicAlbum') return [];

        String includeItemTypes;
        String sortBy;
        if (type == 'Series') {
          includeItemTypes = 'Season';
          sortBy = 'IndexNumber,SortName';
        } else if (type == 'Season') {
          includeItemTypes = 'Episode';
          sortBy = 'IndexNumber,SortName';
        } else if (type == 'MusicArtist') {
          includeItemTypes = 'MusicAlbum';
          sortBy = 'ProductionYear,SortName';
        } else {
          includeItemTypes = 'Audio';
          sortBy = 'ParentIndexNumber,IndexNumber,SortName';
        }

        final data = await apiService.getItems(
          user.userId,
          parentId: params.itemId,
          includeItemTypes: includeItemTypes,
          sortBy: sortBy,
          sortOrder: 'Ascending',
          fields: (type == 'Season' || type == 'MusicAlbum') ? 'Overview' : null,
        );

        return (data['Items'] as List).map((e) => e as Map<String, dynamic>).toList();
      } catch (e) {
        logError('Failed to fetch item children: $e');
        return [];
      }
    });
