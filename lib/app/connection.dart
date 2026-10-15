import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Whether the phone has a network at all (Wi-Fi or mobile data). It can't promise the internet
/// works, only that it certainly doesn't when this is false, which is when the app says so up
/// front instead of letting a payment spin.
class Connection {
  Connection._();
  static final instance = Connection._();

  final online = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> start() async {
    if (_sub != null) return;
    try {
      final c = Connectivity();
      _sub = c.onConnectivityChanged.listen(_set, onError: (_) {});
      _set(await c.checkConnectivity());
    } catch (e) {
      // No plugin (tests, desktop): assume online and let calls fail on their own.
      debugPrint('connectivity unavailable: $e');
    }
  }

  void _set(List<ConnectivityResult> r) => online.value = r.any((x) => x != ConnectivityResult.none);

  bool get isOffline => !online.value;
}
