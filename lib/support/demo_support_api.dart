import 'dart:async';

import 'support_api.dart';

/// Stand-in support desk for demo mode: "Konduct support" answers two seconds after you write.
class DemoSupportApi extends SupportApi {
  final _threads = <SupportThread>[];
  final _messages = <String, List<SupportMessage>>{};
  final _changed = StreamController<void>.broadcast();
  var _n = 0;

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    yield* _changed.stream.map((_) => read());
  }

  void _touch() => _changed.add(null);

  @override
  Stream<List<SupportThread>> threads() => _live(() => List.of(_threads)..sort((a, b) => b.lastAt.compareTo(a.lastAt)));

  @override
  Stream<List<SupportMessage>> messages(String threadId) => _live(() => List.of(_messages[threadId] ?? const []));

  @override
  Future<String> open({required SupportCategory category, required String message, String? txId}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 'demothread${++_n}';
    _messages[id] = [];
    _threads.add(SupportThread(id: id, category: category, open: true, lastText: message, lastFromStaff: false, lastAt: DateTime.now(), readAt: DateTime.now(), txId: txId));
    _add(id, message, staff: false);
    Future.delayed(const Duration(seconds: 2), () => _add(id, 'Thanks for writing. Bisi from Konduct support here. We\'re looking into it and will reply shortly.', staff: true));
    return id;
  }

  @override
  Future<void> send(String threadId, String text) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _add(threadId, text, staff: false);
  }

  @override
  Future<void> markRead(String threadId) async {
    final i = _threads.indexWhere((t) => t.id == threadId);
    if (i < 0) return;
    final t = _threads[i];
    _threads[i] = SupportThread(id: t.id, category: t.category, open: t.open, lastText: t.lastText, lastFromStaff: t.lastFromStaff, lastAt: t.lastAt, readAt: DateTime.now(), txId: t.txId);
    _touch();
  }

  void _add(String threadId, String text, {required bool staff}) {
    final now = DateTime.now();
    _messages[threadId]!.add(SupportMessage(id: 'm${++_n}', fromStaff: staff, authorName: staff ? 'Bisi' : '', text: text, at: now));
    final i = _threads.indexWhere((t) => t.id == threadId);
    final t = _threads[i];
    _threads[i] = SupportThread(
      id: t.id,
      category: t.category,
      open: true,
      lastText: text,
      lastFromStaff: staff,
      lastAt: now,
      readAt: staff ? t.readAt : now,
      txId: t.txId,
    );
    _touch();
  }
}
