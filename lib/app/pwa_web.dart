import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// The browser's install offer, kept by web/index.html (Chrome and Edge fire it once, early).
@JS('konductInstallPrompt')
external JSObject? get _prompt;
@JS('konductInstallPrompt')
external set _prompt(JSObject? v);

extension type _InstallPrompt(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
}

abstract final class Pwa {
  /// Opened from the home screen, not in a browser tab.
  static bool get standalone {
    if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
    // Safari on iPhone says so its own way.
    return (web.window.navigator as JSObject).getProperty<JSAny?>('standalone'.toJS).dartify() == true;
  }

  /// iPhone or iPad: no install button, only Share → Add to Home Screen.
  static bool get isIos {
    final nav = web.window.navigator;
    if (RegExp('iPhone|iPad|iPod').hasMatch(nav.userAgent)) return true;
    // iPadOS asks for desktop sites and says it's a Mac.
    return nav.platform == 'MacIntel' && nav.maxTouchPoints > 1;
  }

  /// True while the browser offers to install the app (Android Chrome, desktop Chrome and Edge).
  static final installable = ValueNotifier<bool>(false);

  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    installable.value = _prompt != null;
    web.window.addEventListener('konduct-installable', ((web.Event _) => installable.value = _prompt != null).toJS);
  }

  /// Shows the browser's install dialog. Call it straight from a tap.
  static Future<void> install() async {
    final p = _prompt;
    if (p == null) return;
    _prompt = null;
    installable.value = false;
    try {
      await _InstallPrompt(p).prompt().toDart;
    } catch (_) {}
  }

  /// Drops a home-screen shortcut's ?action=… from the address, so a reload doesn't repeat it.
  static void forgetLaunchQuery() {
    final l = web.window.location;
    if (l.search.isEmpty) return;
    web.window.history.replaceState(null, '', '${l.pathname}${l.hash}');
  }
}
