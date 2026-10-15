import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_info.dart';

/// Compares this build with config/app (konduct-backend domain/appversion.ts): below minBuild the
/// app can only be updated; below latestBuild it offers the update. Live, so raising the minimum
/// takes effect on phones that are already open.
class VersionCheck extends ChangeNotifier {
  VersionCheck._();
  static final instance = VersionCheck._();

  int? build;
  bool mustUpdate = false;
  bool canUpdate = false;
  String? updateUrl;
  StreamSubscription<Object?>? _sub;

  /// [live]: false in demo mode, where there is no backend to ask.
  Future<void> start({required bool live}) async {
    if (_sub != null) return;
    try {
      build = int.tryParse((await PackageInfo.fromPlatform()).buildNumber);
    } catch (_) {}
    if (!live || build == null) return;
    _sub = FirebaseFirestore.instance.doc('config/app').snapshots().listen((s) => apply(s.data()?[AppInfo.role]), onError: (_) {});
  }

  /// [entry] is this app's part of config/app: `{ minBuild, latestBuild, updateUrl }`.
  @visibleForTesting
  void apply(Object? entry) {
    final b = build;
    if (b == null) return;
    final m = entry is Map ? entry : const {};
    final min = (m['minBuild'] as num?)?.toInt() ?? 0;
    final latest = (m['latestBuild'] as num?)?.toInt() ?? 0;
    final url = m['updateUrl'] as String?;
    final must = b < min;
    final can = !must && b < latest;
    if (must == mustUpdate && can == canUpdate && url == updateUrl) return;
    mustUpdate = must;
    canUpdate = can;
    updateUrl = url != null && url.startsWith('https://') ? url : null;
    notifyListeners();
  }
}
