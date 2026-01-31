import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'smooth_animated_slider.dart';

String formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

class PlaybackProgressControl extends StatefulWidget {
  final int currentPositionSeconds;
  final int durationSeconds;
  final bool isPlaying;
  final bool interactable;
  final ValueChanged<int>? onSeek;
  final ValueChanged<int>? onSeekEnd;
  final Widget Function(BuildContext context, double value, double thumbCenter)?
  overlayBuilder;
  final double width;

  const PlaybackProgressControl({
    super.key,
    required this.currentPositionSeconds,
    required this.durationSeconds,
    required this.isPlaying,
    this.interactable = true,
    this.onSeek,
    this.onSeekEnd,
    this.overlayBuilder,
    this.width = 0,
  });

  @override
  State<PlaybackProgressControl> createState() =>
      _PlaybackProgressControlState();
}

class _PlaybackProgressControlState extends State<PlaybackProgressControl> {
  bool _isDragging = false;
  double _dragValue = 0;
  int _animationKeyIndex = 0;
  double? _forceBeginValue;

  @override
  Widget build(BuildContext context) {
    final double duration = widget.durationSeconds.toDouble();
    final double max = duration > 0 ? duration : 1.0;
    final double targetValue = widget.currentPositionSeconds.toDouble().clamp(
      0.0,
      max,
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey(_animationKeyIndex),
      tween: Tween<double>(begin: _forceBeginValue, end: targetValue),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, animatedValue, child) {
        final double displayValue = _isDragging ? _dragValue : animatedValue;
        final double clampedDisplay = displayValue.clamp(0.0, max);

        return Column(
          children: [
            if (widget.interactable)
              Builder(
                builder: (context) {
                  return SmoothAnimatedSlider(
                    value: clampedDisplay,
                    max: max,
                    width: widget.width,
                    onChanged: widget.onSeek != null
                        ? (value) {
                            setState(() {
                              _isDragging = true;
                              _dragValue = value;
                            });
                            widget.onSeek?.call(value.toInt());
                          }
                        : null,
                    onChangeEnd: widget.onSeekEnd != null
                        ? (value) {
                            setState(() {
                              _isDragging = false;
                              _animationKeyIndex++;
                              _forceBeginValue = value;
                            });
                            HapticFeedback.lightImpact();
                            widget.onSeekEnd?.call(value.toInt());
                          }
                        : null,
                    overlayBuilder: widget.overlayBuilder != null
                        ? (context, value, thumbCenter) =>
                            widget.overlayBuilder!(context, value, thumbCenter)
                        : null,
                  );
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max > 0 ? clampedDisplay / max : 0,
                    minHeight: 6,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(clampedDisplay.toInt())),
                  Text(formatDuration(widget.durationSeconds)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
