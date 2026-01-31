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
        return await apiService.getItemDetails(
          user.userId,
          itemId,
        );
      } catch (e) {
        logError('Failed to fetch item details: $e');
        return null;
      }
    });

final playbackInfoProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, itemId) async {
      final authState = ref.watch(authProvider);
      final user = authState.currentUser;
      final apiService = ref.read(apiServiceProvider);

      if (user == null) return null;

      try {
        return await apiService.getPlaybackInfo(
          user.userId,
          itemId,
        );
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
        return await apiService.getLyrics(
          params.itemId,
        );
      } catch (e) {
        logError('Failed to fetch lyrics: $e');
        return null;
      }
    });
