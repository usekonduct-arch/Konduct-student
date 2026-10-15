import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_info.dart';
import '../l10n/l10n.dart';
import 'messages_api.dart';

class FirebaseMessagesApi extends MessagesApi {
  final _db = FirebaseFirestore.instance;
  final _pushes = StreamController<PushEvent>.broadcast();
  bool _pushStarted = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Stream<Brand> brand() => _db.doc('config/brand').snapshots().map((s) => Brand.fromMap(s.data())).handleError((_) {});

  @override
  Stream<List<Notice>> notices() {
    final personal = _db
        .collection('users/$_uid/notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((q) => q.docs.map((d) => _notice(d.id, d.data(), personal: true)).toList());
    final group = _db
        .collection('broadcasts')
        .where('active', isEqualTo: true)
        .where('audience', whereIn: ['all', AppInfo.role])
        .orderBy('createdAtMs', descending: true)
        .limit(30)
        .snapshots()
        .map((q) => q.docs.map((d) => _notice(d.id, d.data(), personal: false)).toList());
    late StreamController<List<Notice>> c;
    final subs = <StreamSubscription<Object?>>[];
    List<Notice>? a, b;
    void emit() {
      if (a == null || b == null) return;
      // Group messages are read on this phone only.
      final all = [...a!, for (final n in b!) seen.has('read:${n.key}') ? n.markedRead() : n]..sort((x, y) => y.at.compareTo(x.at));
      c.add(all);
    }

    c = StreamController<List<Notice>>(
      onListen: () async {
        await seen.ready();
        subs
          ..add(
            personal.listen(
              (v) {
                a = v;
                emit();
              },
              onError: (_) {
                a = const [];
                emit();
              },
            ),
          )
          // A missing index or a rules change mustn't hide personal messages.
          ..add(
            group.listen(
              (v) {
                b = v;
                emit();
              },
              onError: (_) {
                b = const [];
                emit();
              },
            ),
          )
          ..add(seen.changes.listen((_) => emit()));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return c.stream;
  }

  Notice _notice(String id, Map<String, dynamic> m, {required bool personal}) {
    final at = (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch((m['createdAtMs'] as num?)?.toInt() ?? 0);
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    return Notice(
      id: id,
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      at: at,
      personal: personal,
      kind: m['kind'] as String? ?? (personal ? '' : 'broadcast'),
      imageUrl: text(m['imageUrl']),
      link: text(m['link']),
      linkLabel: text(m['linkLabel']),
      popup: m['popup'] == true,
      read: personal && m['read'] == true,
    );
  }

  @override
  Future<void> markRead(Notice n) async {
    if (n.read) return;
    if (!n.personal) return seen.add('read:${n.key}');
    try {
      await _db.doc('users/$_uid/notifications/${n.id}').update({'read': true});
    } catch (_) {
      // Only the unread dot depends on this.
    }
  }

  @override
  Stream<List<Ad>> ads() => _db
      .collection('ads')
      .where('active', isEqualTo: true)
      .where('audience', whereIn: ['all', AppInfo.role])
      .snapshots()
      .map((q) => q.docs.map((d) => Ad.fromMap(d.id, d.data())).whereType<Ad>().toList()..sort((x, y) => x.order.compareTo(y.order)))
      .handleError((_) {});

  @override
  Stream<PushEvent> pushes() => _pushes.stream;

  @override
  Future<void> startPush() async {
    if (_pushStarted) return;
    _pushStarted = true;
    final fcm = FirebaseMessaging.instance;
    try {
      final perm = await fcm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      FirebaseMessaging.onMessage.listen((m) => _pushes.add(_event(m, tapped: false)));
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _pushes.add(_event(m, tapped: true)));
      final first = await fcm.getInitialMessage();
      if (first != null) _pushes.add(_event(first, tapped: true));
      final token = await fcm.getToken();
      if (token != null) await _register(token);
      fcm.onTokenRefresh.listen(_register);
    } catch (e) {
      // Push is a nicety: the inbox still fills from Firestore.
      debugPrint('push setup failed: $e');
      _pushStarted = false;
    }
  }

  PushEvent _event(RemoteMessage m, {required bool tapped}) => PushEvent(
    title: m.notification?.title ?? m.data['title'] as String? ?? '',
    body: m.notification?.body ?? m.data['body'] as String? ?? '',
    kind: m.data['kind'] as String? ?? '',
    link: (m.data['link'] as String?)?.isNotEmpty == true ? m.data['link'] as String : null,
    popup: m.data['popup'] == '1',
    tapped: tapped,
    data: m.data,
  );

  HttpsCallable _callable(String name) {
    final functions = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);
    return AppConfig.backendUrl.isEmpty ? functions.httpsCallable(name) : functions.httpsCallableFromUrl('${AppConfig.backendUrl}/$name');
  }

  Future<void> _register(String token) async {
    try {
      await _callable('registerDevice').call<Object?>({
        'deviceId': await _deviceId(),
        'fcmToken': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'lang': L10n.instance.lang.code,
      });
    } catch (e) {
      debugPrint('registerDevice failed: $e');
    }
  }

  @override
  Future<void> setLanguage(String code) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await _callable('setLanguage').call<Object?>({'lang': code});
    } catch (e) {
      // The next registerDevice sends it again.
      debugPrint('setLanguage failed: $e');
    }
  }

  /// A random id for this install, kept so re-registering replaces the old token.
  static Future<String> _deviceId() async {
    const key = 'konduct.deviceId';
    try {
      final p = await SharedPreferences.getInstance();
      final had = p.getString(key);
      if (had != null) return had;
      final made = _randomId();
      await p.setString(key, made);
      return made;
    } catch (_) {
      return _randomId();
    }
  }

  static String _randomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
