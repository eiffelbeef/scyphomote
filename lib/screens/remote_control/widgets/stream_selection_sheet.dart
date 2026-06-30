import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/remote_providers.dart';
import '../../../providers/session_provider.dart';
import '../../../providers/playback_provider.dart';

class StreamSelectionSheet extends ConsumerStatefulWidget {
  final String itemId;
  final String streamType; // 'Audio' or 'Subtitle'
  final String title;

  const StreamSelectionSheet({
    super.key,
    required this.itemId,
    required this.streamType,
    required this.title,
  });

  @override
  ConsumerState<StreamSelectionSheet> createState() =>
      _StreamSelectionSheetState();
}

class _StreamSelectionSheetState extends ConsumerState<StreamSelectionSheet> {
  // -2 means not initialized yet (use server data)
  // -1 means "None" (for subtitles)
  // >= 0 is a specific stream index
  int _optimisticSelection = -2;

  @override
  Widget build(BuildContext context) {
    // Watch item details to get the list of streams
    final itemDetailsAsync = ref.watch(itemDetailsProvider(widget.itemId));

    return itemDetailsAsync.when(
      data: (details) {
        if (details == null) {
          return const Center(child: Text('Failed to load item details'));
        }

        final streams = (details['MediaStreams'] as List? ?? [])
            .where((s) => s['Type'] == widget.streamType)
            .toList();

        if (streams.isEmpty) {
          return Center(
            child: Text('No ${widget.streamType.toLowerCase()}s available'),
          );
        }

        final currentSession = ref.watch(sessionProvider).selectedSession;
        final playState = currentSession?.playState;

        final int? serverIndex = widget.streamType == 'Subtitle'
            ? playState?.subtitleStreamIndex
            : playState?.audioStreamIndex;

        final effectiveIndex = _optimisticSelection != -2
            ? _optimisticSelection
            : (serverIndex ?? -1);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount:
                    streams.length + (widget.streamType == 'Subtitle' ? 1 : 0),
                itemBuilder: (context, index) {
                  // Handle "None" option for Subtitles (index 0)
                  if (widget.streamType == 'Subtitle' && index == 0) {
                    final isNone = effectiveIndex == -1;

                    return ListTile(
                      title: const Text('None'),
                      trailing: isNone
                          ? const Icon(Icons.check_rounded, color: Colors.green)
                          : null,
                      onTap: () => _handleSelection(-1),
                    );
                  }

                  // Adjust index for streams list if we have "None" option
                  final listIndex = widget.streamType == 'Subtitle'
                      ? index - 1
                      : index;
                  final stream = streams[listIndex];
                  final streamIndex = stream['Index'] as int;
                  final isSelected = streamIndex == effectiveIndex;

                  return _buildStreamTile(
                    stream,
                    isSelected,
                    () => _handleSelection(streamIndex),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) =>
          SizedBox(height: 200, child: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildStreamTile(
    Map<String, dynamic> stream,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final language = stream['Language'] ?? 'Unknown';
    final displayTitle = stream['DisplayTitle'] ?? stream['Title'];

    final (titleText, subtitleText) = switch (widget.streamType) {
      'Audio' => (
          displayTitle ?? 'Audio Track',
          '${language.toUpperCase()} • ${stream['Codec'] ?? ''} • ${stream['Channels'] ?? 0}ch'
        ),
      _ => (
          displayTitle ?? 'Subtitle',
          language.toUpperCase()
        ),
    };

    return ListTile(
      title: Text(titleText),
      subtitle: Text(subtitleText),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.green)
          : null,
      onTap: onTap,
    );
  }

  Future<void> _handleSelection(int index) async {
    HapticFeedback.lightImpact();

    // Update optimistic state immediately
    setState(() {
      _optimisticSelection = index;
    });

    if (widget.streamType == 'Subtitle') {
      ref.read(playbackProvider.notifier).setSubtitleStreamIndex(index);
    } else {
      ref.read(playbackProvider.notifier).setAudioStreamIndex(index);
    }

    // Wait a bit for visual feedback before closing
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.pop(context);
  }
}
