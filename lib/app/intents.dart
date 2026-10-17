import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import '../l10n/l10n.dart';
import 'app_info.dart';
import 'pwa.dart';

/// Ways into a screen from outside the app: a long-press shortcut on the app icon, a link
/// (konduct://pay?code=AB12CD, https://konduct.com.ng/pay/AB12CD), or a tap on the home-screen widget.
/// Each becomes an `app:` link (messages_ui.dart openLink) that waits in [pending] until the home
/// screen is up and signed in to open it.
class AppIntents {
  AppIntents._();
  static final instance = AppIntents._();

  /// The next `app:` link to open, or null.
  final pending = ValueNotifier<String?>(null);

  bool _started = false;

  /// Reads the link or shortcut that launched the app and listens for more. Never throws:
  /// every source is optional.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (kIsWeb) {
      // The installed web app's shortcuts (web/manifest.json) open ./?action=scan and the like.
      Pwa.start();
      final action = Uri.base.queryParameters['action']?.toLowerCase();
      if (action != null && AppInfo.linkScreens.contains(action)) _take('app:$action');
      Pwa.forgetLaunchQuery();
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      final links = AppLinks();
      links.uriLinkStream.listen((u) => _take(linkFor(u)), onError: (_) {});
      _take(linkFor(await links.getInitialLink()));
    } catch (e) {
      debugPrint('app links unavailable: $e');
    }

    try {
      HomeWidget.widgetClicked.listen((u) => _take(linkFor(u)), onError: (_) {});
      _take(linkFor(await HomeWidget.initiallyLaunchedFromHomeWidget()));
    } catch (e) {
      debugPrint('home widget unavailable: $e');
    }

    try {
      const actions = QuickActions();
      await actions.initialize((type) => _take('app:$type'));
      await setShortcuts();
      L10n.instance.onChanged((_) => setShortcuts());
    } catch (e) {
      debugPrint('quick actions unavailable: $e');
    }
  }

  /// The icon's long-press menu, in the app's language.
  Future<void> setShortcuts() => const QuickActions().setShortcutItems([
    for (final s in AppInfo.shortcuts) ShortcutItem(type: s.$1, localizedTitle: tr(s.$2), icon: s.$3),
  ]);

  void _take(String? link) {
    if (link != null) pending.value = link;
  }

  /// The `app:` link a URI asks for, or null for one that only opens the app.
  static String? linkFor(Uri? u) {
    if (u == null) return null;
    final https = u.scheme == 'https' && AppInfo.linkHosts.contains(u.host);
    if (u.scheme != AppInfo.linkScheme && u.scheme != 'konduct-widget' && !https) return null;
    // konduct://pay?code=X has the screen as the host; https://konduct.com.ng/pay/X has it as the path.
    final parts = [if (!https && u.host.isNotEmpty) u.host, ...u.pathSegments.where((p) => p.isNotEmpty)];
    if (parts.isEmpty) return null;
    final screen = parts.first.toLowerCase();
    final arg = u.queryParameters['code'] ?? u.queryParameters['id'] ?? (parts.length > 1 ? parts[1] : '');
    if (!AppInfo.linkScreens.contains(screen)) return null;
    // Only letters, digits, dash and underscore reach a screen: a link can't smuggle anything else in.
    final safe = arg.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return safe.isEmpty ? 'app:$screen' : 'app:$screen/$safe';
  }
}
