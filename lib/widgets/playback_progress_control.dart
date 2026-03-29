import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../utils/ui_utils.dart';
import 'smooth_animated_slider.dart';

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

class _PlaybackProgressControlState extends State<PlaybackProgressControl>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _currentExtrapolatedPosition = 0;

  int _lastServerPosition = 0;
  DateTime? _lastServerUpdateTime;
  double _playbackSpeed = 1.0;
  bool _isFirstUpdateSincePlay = true;

  bool _isDragging = false;
  double _dragValue = 0;
  bool _showSpeedText = false;

  @override
  void initState() {
    super.initState();
    _lastServerPosition = widget.currentPositionSeconds;
    _currentExtrapolatedPosition = widget.currentPositionSeconds.toDouble();
    if (widget.isPlaying) {
      _lastServerUpdateTime = DateTime.now();
      _isFirstUpdateSincePlay = true;
    }
    _ticker = createTicker(_onTick);
    if (widget.isPlaying) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!widget.isPlaying || _isDragging) return;

    if (_lastServerUpdateTime != null) {
      final double timeElapsedSec =
          DateTime.now().difference(_lastServerUpdateTime!).inMilliseconds /
          1000.0;

      final double targetPosition =
          _lastServerPosition + (timeElapsedSec * _playbackSpeed);

      setState(() {
        // Smoothly asymptotic approach (lerp) to the target to avoid teleports when server updates.
        _currentExtrapolatedPosition +=
            (targetPosition - _currentExtrapolatedPosition) * 0.2;
        _currentExtrapolatedPosition = _currentExtrapolatedPosition.clamp(
          0.0,
          widget.durationSeconds.toDouble(),
        );
      });
    }
  }

  @override
  void didUpdateWidget(PlaybackProgressControl oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _lastServerUpdateTime = DateTime.now();
        _isFirstUpdateSincePlay = true;
        _ticker.start();
      } else {
        _ticker.stop();
        _lastServerUpdateTime = null;
      }
    }

    if (widget.currentPositionSeconds != oldWidget.currentPositionSeconds) {
      final DateTime now = DateTime.now();
      if (_lastServerUpdateTime != null && oldWidget.isPlaying) {
        final int durationDiff =
            widget.currentPositionSeconds - _lastServerPosition;
        final int timeElapsedMs = now
            .difference(_lastServerUpdateTime!)
            .inMilliseconds;

        if (!_isFirstUpdateSincePlay && timeElapsedMs > 0) {
          final double calculatedSpeed =
              (durationDiff * 1000.0) / timeElapsedMs;

          // Only accept naturally derived non-seek playback rates (between 0.25x and 4.0x)
          if (calculatedSpeed >= 0.25 && calculatedSpeed <= 4.0) {
            _playbackSpeed = calculatedSpeed;
          } else {
            // Unrealistic jump, indicating a seek or stall
            _playbackSpeed = 1.0;
          }
        }

        _isFirstUpdateSincePlay = false;
      }
      _lastServerPosition = widget.currentPositionSeconds;
      _lastServerUpdateTime = now;

      if (!widget.isPlaying) {
        _currentExtrapolatedPosition = widget.currentPositionSeconds.toDouble();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double duration = widget.durationSeconds.toDouble();
    final double max = duration > 0 ? duration : 1.0;

    final double displayValue = _isDragging
        ? _dragValue
        : _currentExtrapolatedPosition;
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
                duration: widget.isPlaying
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                onChanged: widget.onSeek != null
                    ? (value) {
                        if (!_isDragging) {
                          setState(() {
                            _isDragging = true;
                          });
                        }
                        setState(() {
                          _dragValue = value;
                        });
                        widget.onSeek?.call(value.toInt());
                      }
                    : null,
                onChangeEnd: widget.onSeekEnd != null
                    ? (value) {
                        setState(() {
                          _isDragging = false;
                          _currentExtrapolatedPosition = value;
                          _lastServerPosition = value.toInt();
                          _lastServerUpdateTime = DateTime.now();
                          _isFirstUpdateSincePlay = true;
                        });
                        HapticFeedback.lightImpact();
                        widget.onSeekEnd?.call(value.toInt());
                      }
                    : null,
                overlayBuilder: widget.overlayBuilder,
              );
            },
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Invisible text to lock the layout width to the longest duration string possible
                      Text(
                        formatDuration(widget.durationSeconds),
                        style: const TextStyle(
                          color: Colors.transparent,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        formatDuration(clampedDisplay.toInt()),
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (_playbackSpeed > 1.1 || _playbackSpeed < 0.9) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _showSpeedText = !_showSpeedText;
                        });
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _showSpeedText
                            ? Text(
                                '~${_playbackSpeed.toStringAsFixed(1)}x',
                                key: const ValueKey('text'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              )
                            : Icon(
                                _playbackSpeed > 1.1
                                    ? CupertinoIcons.hare
                                    : CupertinoIcons.tortoise,
                                key: const ValueKey('icon'),
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                formatDuration(widget.durationSeconds),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
