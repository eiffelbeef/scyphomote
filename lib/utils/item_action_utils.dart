import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/remote_providers.dart';
import '../services/jellyfin_api_service.dart';
import 'ui_utils.dart';

class ItemActionUtils {
  static Future<void> _performToggle(
    BuildContext context,
    WidgetRef ref,
    String itemId,
    String errorMessage,
    Future<void> Function(JellyfinApiService apiService, String userId) action,
  ) async {
    HapticFeedback.lightImpact();
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    final apiService = ref.read(apiServiceProvider);
    try {
      await action(apiService, user.userId);
      ref.invalidate(itemDetailsProvider(itemId));
    } catch (e) {
      if (context.mounted) {
        UiUtils.showSnackBar(context, errorMessage);
      }
    }
  }

  static Future<void> toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    String itemId,
    bool currentlyFavorite,
  ) => _performToggle(
        context,
        ref,
        itemId,
        'Failed to update favorite status',
        (api, userId) => api.toggleFavorite(userId, itemId, currentlyFavorite),
      );

  static Future<void> togglePlayedStatus(
    BuildContext context,
    WidgetRef ref,
    String itemId,
    bool currentlyPlayed,
  ) => _performToggle(
        context,
        ref,
        itemId,
        'Failed to update played status',
        (api, userId) => api.togglePlayedStatus(userId, itemId, currentlyPlayed),
      );
}
