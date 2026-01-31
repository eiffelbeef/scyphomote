import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_account.dart';

class UserAvatar extends StatelessWidget {
  final UserAccount user;
  final double? radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        user.profileImageBase64 != null && user.profileImageBase64!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: foregroundColor,
      backgroundImage: hasImage
          ? MemoryImage(base64Decode(user.profileImageBase64!))
          : null,
      child: !hasImage
          ? Text(
              user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
              style: TextStyle(
                color:
                    foregroundColor ??
                    Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}
