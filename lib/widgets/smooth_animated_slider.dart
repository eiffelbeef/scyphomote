import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef SmoothSliderOverlayBuilder = Widget Function(
  BuildContext context,
  double value,
  double thumbCenter,
);

class SmoothAnimatedSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double width;
  final double padding;
  final Duration duration;
  final Curve curve;
  final SmoothSliderOverlayBuilder? overlayBuilder;

  const SmoothAnimatedSlider({
    super.key,
    required this.value,
    this.min = 0,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    required this.width,
    this.padding = 24.0,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeInOut,
    this.overlayBuilder,
  });

  @override
  State<SmoothAnimatedSlider> createState() => _SmoothAnimatedSliderState();
}

class _SmoothAnimatedSliderState extends State<SmoothAnimatedSlider> {
  bool _isDragging = false;
  double _dragValue = 0;
  int _animationKeyIndex = 0;
  double? _forceBeginValue;

  @override
  Widget build(BuildContext context) {
    // We assume widget.max > widget.min
    final double rangeMin = widget.min;
    final double rangeMax = widget.max;
    final double targetValue = widget.value.clamp(rangeMin, rangeMax);

    return TweenAnimationBuilder<double>(
      key: ValueKey(_animationKeyIndex),
      tween: Tween<double>(begin: _forceBeginValue, end: targetValue),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, animatedValue, child) {
        final double displayValue = _isDragging ? _dragValue : animatedValue;
        final double clampedDisplay = displayValue.clamp(rangeMin, rangeMax);

        // Compute thumb position for overlay placement
        final availableTrackWidth = widget.width - (widget.padding * 2);
        final double fraction = (clampedDisplay - rangeMin) / (rangeMax - rangeMin);
        final thumbPos = fraction * availableTrackWidth + widget.padding;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Slider(
              value: clampedDisplay,
              min: rangeMin,
              max: rangeMax,
              onChanged: widget.onChanged != null
                  ? (value) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = value;
                      });
                      widget.onChanged?.call(value);
                    }
                  : null,
              onChangeEnd: widget.onChangeEnd != null
                  ? (value) {
                      setState(() {
                        _isDragging = false;
                        _animationKeyIndex++;
                        _forceBeginValue = value;
                      });
                      HapticFeedback.lightImpact();
                      widget.onChangeEnd?.call(value);
                    }
                  : null,
            ),
            if (_isDragging && widget.overlayBuilder != null)
              Positioned(
                left: thumbPos,
                bottom: 40,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, 0),
                  child: widget.overlayBuilder!(context, clampedDisplay, thumbPos),
                ),
              ),
          ],
        );
      },
    );
  }
}
