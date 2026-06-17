import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'session_provider.dart';
import '../models/media_info.dart';

class QueueDetailsNotifier extends Notifier<Map<String, MediaInfo>> {
  @override
  Map<String, MediaInfo> build() {
    ref.listen(sessionProvider.select((s) => s.selectedSession?.nowPlayingQueue), (previous, next) {
      if (next != null && next.isNotEmpty) {
        _fetchMissing(next);
      }
    });

    final queue = ref.read(sessionProvider).selectedSession?.nowPlayingQueue;
    if (queue != null && queue.isNotEmpty) {
      Future.microtask(() => _fetchMissing(queue));
    }
    
    return {};
  }

  Future<void> _fetchMissing(List<MediaInfo> queue) async {
    final needsFetching = queue
        .where((i) => i.name == null && !state.containsKey(i.id))
        .map((i) => i.id)
        .toSet()
        .toList();
        
    if (needsFetching.isEmpty) return;

    final apiService = ref.read(apiServiceProvider);
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    try {
      final idString = needsFetching.join(',');
      final response = await apiService.getItems(user.userId, ids: idString);
      final items = response['Items'] as List;
      final map = <String, MediaInfo>{};
      for (var item in items) {
        final info = MediaInfo.fromJson(item as Map<String, dynamic>);
        map[info.id] = info;
      }
      
      state = {...state, ...map};
    } catch (e, stackTrace) {
      debugPrint('Failed to bulk fetch queue details: $e\n$stackTrace');
    }
  }
}

final queueDetailsProvider = NotifierProvider<QueueDetailsNotifier, Map<String, MediaInfo>>(() {
  return QueueDetailsNotifier();
});
