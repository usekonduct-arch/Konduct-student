import 'package:flutter/foundation.dart';

/// Not a browser: there's nothing to install.
abstract final class Pwa {
  static bool get standalone => true;
  static bool get isIos => false;
  static final installable = ValueNotifier<bool>(false);
  static void start() {}
  static Future<void> install() async {}
  static void forgetLaunchQuery() {}
}
