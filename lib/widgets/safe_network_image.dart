import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final Widget fallbackWidget;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallbackWidget,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final content = (imageUrl?.isEmpty ?? true)
        ? fallbackWidget
        : CachedNetworkImage(
            imageUrl: imageUrl!,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, _) => fallbackWidget,
            errorWidget: (_, _, _) => fallbackWidget,
          );

    return borderRadius == null
        ? content
        : ClipRRect(borderRadius: borderRadius!, child: content);
  }
}
