import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/trickplay.dart';
import '../../../providers/auth_provider.dart';

mixin TrickplayFetchMixin<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  Uint8List? imageData;
  int? loadedTilesetIndex;
  int? inFlightTilesetIndex;
  final Set<int> failedIndices = {};

  String get fetchItemId;
  String get fetchMediaSourceId;
  TrickplayInfo get fetchInfo;

  void resetFetchState() {
    imageData = null;
    loadedTilesetIndex = null;
    inFlightTilesetIndex = null;
    failedIndices.clear();
  }

  Future<void> fetchTileset(int tilesetIndex, {VoidCallback? onLoaded}) async {
    if (inFlightTilesetIndex == tilesetIndex ||
        failedIndices.contains(tilesetIndex)) {
      return;
    }
    final fetchedFor = (fetchItemId, fetchMediaSourceId);
    try {
      inFlightTilesetIndex = tilesetIndex;
      final data = await ref.read(apiServiceProvider).getTrickplayTileImage(
            fetchItemId, fetchMediaSourceId, fetchInfo.width, tilesetIndex);
      if (!mounted || (fetchItemId, fetchMediaSourceId) != fetchedFor) return;
      if (data != null) {
        setState(() {
          imageData = data;
          loadedTilesetIndex = tilesetIndex;
          failedIndices.remove(tilesetIndex);
          onLoaded?.call();
        });
      } else {
        setState(() => failedIndices.add(tilesetIndex));
      }
    } catch (_) {
      if (mounted && (fetchItemId, fetchMediaSourceId) == fetchedFor) {
        setState(() => failedIndices.add(tilesetIndex));
      }
    } finally {
      inFlightTilesetIndex = null;
    }
  }
}
