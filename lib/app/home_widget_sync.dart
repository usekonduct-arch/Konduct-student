import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// The Konduct home-screen widget (android/app/src/main/kotlin/.../KonductWidget.kt): a "Scan to
/// pay" button and, if the rider turns it on, their balance as of the last time the app was open.
/// The balance is hidden unless asked for, since anyone can see a home screen.
abstract final class HomeWidgetSync {
  static const _showKey = 'konduct.widgetShowsBalance';
  static const _android = 'KonductWidget';

  /// The figure last written, so turning the setting on can show it straight away.
  static String? _last;

  /// Writes the widget again, for example in a new language.
  static Future<void> refresh() => update(balanceText: _last);

  static Future<bool> showsBalance() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_showKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setShowsBalance(bool on, {String? balanceText}) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_showKey, on);
    } catch (_) {}
    await update(balanceText: balanceText ?? _last);
  }

  /// [balanceText] like "₦1,250"; null when signed out or not loaded.
  static Future<void> update({String? balanceText}) async {
    _last = balanceText;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final show = await showsBalance();
      await HomeWidget.saveWidgetData<String>('title', 'Konduct');
      await HomeWidget.saveWidgetData<String>('value', show && balanceText != null ? balanceText : '');
      await HomeWidget.saveWidgetData<String>('subtitle', show && balanceText != null ? tr('Wallet balance') : tr('Tap to scan and pay'));
      await HomeWidget.saveWidgetData<String>('button', tr('Scan to pay'));
      await HomeWidget.updateWidget(androidName: _android);
    } catch (e) {
      debugPrint('home widget update failed: $e');
    }
  }
}
