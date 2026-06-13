import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ThemedSvgIcon extends StatelessWidget {
  final String asset;
  final double? size;
  final Color? color;

  const ThemedSvgIcon(
    this.asset, {
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final iconColor = color ?? iconTheme.color;
    final iconSize = size ?? iconTheme.size ?? 24.0;
    
    return SvgPicture.asset(
      asset,
      width: iconSize,
      height: iconSize,
      colorFilter: iconColor != null 
          ? ColorFilter.mode(iconColor, BlendMode.srcIn) 
          : null,
    );
  }
}
