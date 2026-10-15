import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A vehicle this rider paid recently, kept on this phone only, so they can pay the same bus
/// again without the camera (a dark bus, a scratched sticker). The confirm screen still shows the
/// plate and driver before any money moves.
class RecentVehicle {
  const RecentVehicle({this.qr, this.code, required this.plate, required this.driver, required this.route, required this.at});

  /// What to price: the sticker's QR text, or the code typed from it.
  final String? qr, code;
  final String plate, driver, route;
  final DateTime at;

  Map<String, Object?> toJson() => {'qr': qr, 'code': code, 'plate': plate, 'driver': driver, 'route': route, 'at': at.millisecondsSinceEpoch};

  static RecentVehicle? fromJson(Object? j) {
    if (j is! Map) return null;
    final plate = j['plate'] as String? ?? '';
    final qr = j['qr'] as String?, code = j['code'] as String?;
    if (plate.isEmpty || (qr == null && code == null)) return null;
    return RecentVehicle(
      qr: qr,
      code: code,
      plate: plate,
      driver: j['driver'] as String? ?? '',
      route: j['route'] as String? ?? '',
      at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
    );
  }
}

/// The last few vehicles paid on this phone, newest first, one per plate, per signed-in rider.
abstract final class RecentVehicles {
  static const _max = 4;
  static String _key(String uid) => 'konduct.recentVehicles.$uid';

  static Future<List<RecentVehicle>> load(String uid) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key(uid));
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).map(RecentVehicle.fromJson).nonNulls.toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> remember(String uid, RecentVehicle v) async {
    try {
      final list = [v, ...(await load(uid)).where((x) => x.plate != v.plate)].take(_max).toList();
      await (await SharedPreferences.getInstance()).setString(_key(uid), jsonEncode([for (final x in list) x.toJson()]));
    } catch (_) {}
  }
}
