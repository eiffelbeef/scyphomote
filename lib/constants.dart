import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Scyphomote';
  static String appVersion = '0.0.0';
  static const String githubUrl = 'https://github.com/EiffelBeef/Scyphomote';
  static const int paginationLimit = 50;

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool isInForeground = true;
}
