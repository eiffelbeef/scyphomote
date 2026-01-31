import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class MarqueeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final double scrollSpeed;
  final double blankSpace;
  final Duration pauseAfterRound;
  final double? maxWidth;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.scrollSpeed = 50.0,
    this.blankSpace = 30.0,
    this.pauseAfterRound = const Duration(seconds: 2),
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.bodyMedium;

    if (maxWidth != null) {
      return _buildContent(
        context,
        BoxConstraints.tightFor(width: maxWidth!),
        effectiveStyle,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildContent(context, constraints, effectiveStyle);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    BoxConstraints constraints,
    TextStyle? style,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    final textWidth = textPainter.width;

    if (textWidth <= constraints.maxWidth) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SizedBox(
      height: textPainter.height,
      child: RepaintBoundary(
        child: Marquee(
          text: text,
          style: style,
          scrollAxis: Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          blankSpace: blankSpace,
          velocity: scrollSpeed,
          pauseAfterRound: pauseAfterRound,
          accelerationDuration: const Duration(milliseconds: 500),
          accelerationCurve: Curves.linear,
          decelerationDuration: const Duration(milliseconds: 200),
          decelerationCurve: Curves.easeOut,
        ),
      ),
    );
  }
}
