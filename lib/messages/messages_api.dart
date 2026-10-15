import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// A message from Konduct: personal (users/{uid}/notifications) or to a whole group (broadcasts).
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.personal,
    this.kind = '',
    this.imageUrl,
    this.link,
    this.linkLabel,
    this.popup = false,
    this.read = false,
  });

  final String id, title, body, kind;
  final DateTime at;

  /// Sent to this person only (read state lives on the server), not to a group.
  final bool personal;
  final String? imageUrl;

  /// An https:// page (opened in the app) or an `app:<screen>` shortcut.
  final String? link;
  final String? linkLabel;

  /// Opens over the app the next time it's in front.
  final bool popup;
  final bool read;

  /// Personal and group ids can't collide in the local "read" list.
  String get key => '${personal ? 'n' : 'b'}:$id';

  Notice markedRead() => Notice(
    id: id,
    title: title,
    body: body,
    at: at,
    personal: personal,
    kind: kind,
    imageUrl: imageUrl,
    link: link,
    linkLabel: linkLabel,
    popup: popup,
    read: true,
  );
}

class AdButton {
  const AdButton(this.label, this.link);
  final String label, link;
}

enum AdPlacement { carousel, popup }

/// ads/{id}: a carousel banner (1200 × 600, 2:1) or a popup (1080 × 1350, 4:5).
class Ad {
  const Ad({
    required this.id,
    required this.placement,
    required this.imageUrl,
    this.title = '',
    this.body = '',
    this.link = '',
    this.buttons = const [],
    this.order = 0,
    this.startsAt,
    this.endsAt,
  });

  final String id, imageUrl, title, body, link;
  final AdPlacement placement;
  final List<AdButton> buttons;
  final int order;
  final DateTime? startsAt, endsAt;

  bool liveAt(DateTime now) => (startsAt == null || !now.isBefore(startsAt!)) && (endsAt == null || now.isBefore(endsAt!));

  static Ad? fromMap(String id, Map<String, dynamic> m) {
    final image = m['imageUrl'] as String? ?? '';
    if (image.isEmpty) return null;
    DateTime? ms(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return Ad(
      id: id,
      placement: m['placement'] == 'popup' ? AdPlacement.popup : AdPlacement.carousel,
      imageUrl: image,
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      link: m['link'] as String? ?? '',
      buttons: [
        for (final b in (m['buttons'] as List? ?? const []).whereType<Map>())
          if ('${b['label'] ?? ''}'.isNotEmpty && '${b['link'] ?? ''}'.isNotEmpty) AdButton('${b['label']}', '${b['link']}'),
      ],
      order: (m['order'] as num?)?.toInt() ?? 0,
      startsAt: ms(m['startsAtMs']),
      endsAt: ms(m['endsAtMs']),
    );
  }
}

/// A push the person tapped, or one that arrived while the app was in front.
class PushEvent {
  const PushEvent({required this.title, required this.body, required this.kind, this.link, this.popup = false, this.tapped = false, this.data = const {}});
  final String title, body, kind;

  /// The push's data fields, such as amountKobo for a spoken money alert.
  final Map<String, dynamic> data;
  final String? link;
  final bool popup;

  /// True when the person opened the app from it; false when it arrived with the app open.
  final bool tapped;
}

/// Notifications, ads and push for one signed-in member.
abstract class MessagesApi {
  /// Personal and group messages, newest first.
  Stream<List<Notice>> notices();

  Future<void> markRead(Notice n);

  /// Ads for this member's group that are switched on (check [Ad.liveAt] for the schedule).
  Stream<List<Ad>> ads();

  /// Asks for permission to notify and registers this phone for push. Safe to call again.
  Future<void> startPush();

  /// Pushes that arrive while the app is open, and ones the person tapped.
  Stream<PushEvent> pushes();

  /// What this phone has already shown, so a popup never shows twice.
  final seen = SeenStore();

  /// Konduct's social handles and hashtag, for the caption when someone shares a ride or their
  /// monthly Wrapped (config/brand, set in the console).
  Stream<Brand> brand() => Stream.value(const Brand());
}

/// Konduct's accounts to tag when sharing. Empty handles are left out of captions.
class Brand {
  const Brand({this.instagram = '', this.x = '', this.tiktok = '', this.facebook = '', this.hashtag = '', this.website = ''});
  final String instagram, x, tiktok, facebook, hashtag, website;

  factory Brand.fromMap(Map<String, dynamic>? m) => Brand(
    instagram: m?['instagram'] as String? ?? '',
    x: m?['x'] as String? ?? '',
    tiktok: m?['tiktok'] as String? ?? '',
    facebook: m?['facebook'] as String? ?? '',
    hashtag: m?['hashtag'] as String? ?? '',
    website: m?['website'] as String? ?? '',
  );

  /// The handles to tag, each once, in the order people are most likely to post.
  List<String> get tags => {instagram, x, tiktok, facebook}.where((h) => h.isNotEmpty).toList();

  /// The hashtag, #RideKonduct until one is set in the console.
  String get tag => hashtag.isEmpty ? '#RideKonduct' : hashtag;

  /// The handles and hashtag printed at the bottom of a share card.
  String get cardTags => [...tags, tag].join(' ');

  /// [lead], then the tags, the hashtag and the website.
  String caption(String lead) => [lead, ...tags, tag, if (website.isNotEmpty) website].join(' ');
}

/// A small set of ids kept on the phone (shared_preferences), falling back to memory when the
/// store can't be opened (tests, a locked-down phone).
class SeenStore {
  static const _key = 'konduct.seen.v1';

  // Under `flutter test` there is no plugin behind shared_preferences; keep ids in memory.
  static final bool _memoryOnly = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  final _ids = <String>{};
  final _changed = StreamController<void>.broadcast();
  Future<void>? _loading;

  Future<void> ready() => _loading ??= _load();

  Future<void> _load() async {
    if (_memoryOnly) return;
    try {
      final p = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      _ids.addAll(p.getStringList(_key) ?? const []);
    } catch (_) {}
  }

  bool has(String id) => _ids.contains(id);

  /// Fires whenever an id is added.
  Stream<void> get changes => _changed.stream;

  Future<void> add(String id) async {
    if (!_ids.add(id)) return;
    _changed.add(null);
    if (_memoryOnly) return;
    try {
      final p = await SharedPreferences.getInstance();
      // Keep the newest few hundred; old ads and messages fall away.
      final list = _ids.toList();
      await p.setStringList(_key, list.length > 400 ? list.sublist(list.length - 400) : list);
    } catch (_) {}
  }
}

/// Stand-in for demo mode and tests: one welcome message, no ads unless given some.
class DemoMessagesApi extends MessagesApi {
  DemoMessagesApi({List<Ad> ads = const [], List<Notice>? notices})
    : _ads = ads,
      _notices =
          notices ??
          [Notice(id: 'welcome', title: 'Welcome to Konduct', body: 'Messages from the Konduct team show up here.', at: DateTime.now(), personal: true)];

  final List<Ad> _ads;
  final List<Notice> _notices;
  final _changed = StreamController<void>.broadcast();
  final _pushes = StreamController<PushEvent>.broadcast();

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    yield* _changed.stream.map((_) => read());
  }

  @override
  Stream<List<Notice>> notices() => _live(() => [..._notices]..sort((a, b) => b.at.compareTo(a.at)));

  @override
  Future<void> markRead(Notice n) async {
    final i = _notices.indexWhere((x) => x.key == n.key);
    if (i >= 0) _notices[i] = _notices[i].markedRead();
    _changed.add(null);
  }

  @override
  Stream<List<Ad>> ads() => Stream.value(_ads);

  @override
  Future<void> startPush() async {}

  @override
  Stream<PushEvent> pushes() => _pushes.stream;

  /// Tests: pretend a push arrived.
  void simulatePush(PushEvent e) => _pushes.add(e);
}
