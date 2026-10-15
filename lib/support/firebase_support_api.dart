import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/app_info.dart';
import '../wallet/models.dart' show ApiException;
import 'support_api.dart';

class FirebaseSupportApi extends SupportApi {
  FirebaseSupportApi() : _functions = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static DateTime _ms(Object? v) => DateTime.fromMillisecondsSinceEpoch((v as num?)?.toInt() ?? 0);

  @override
  Stream<List<SupportThread>> threads() => _db
      .collection('supportThreads')
      .where('uid', isEqualTo: _uid)
      .orderBy('lastAtMs', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (q) => q.docs.map((d) {
          final m = d.data();
          return SupportThread(
            id: d.id,
            category: SupportCategory.of(m['category'] as String?),
            open: m['status'] != 'closed',
            lastText: m['lastText'] as String? ?? '',
            lastFromStaff: m['lastFrom'] == 'staff',
            lastAt: _ms(m['lastAtMs']),
            readAt: _ms(m['memberReadAtMs']),
            txId: m['txId'] as String?,
          );
        }).toList(),
      );

  @override
  Stream<List<SupportMessage>> messages(String threadId) => _db
      .collection('supportThreads/$threadId/messages')
      .orderBy('atMs')
      .limitToLast(200)
      .snapshots()
      .map(
        (q) => q.docs.map((d) {
          final m = d.data();
          return SupportMessage(
            id: d.id,
            fromStaff: m['from'] == 'staff',
            authorName: m['authorName'] as String? ?? '',
            text: m['text'] as String? ?? '',
            at: _ms(m['atMs']),
          );
        }).toList(),
      );

  @override
  Future<String> open({required SupportCategory category, required String message, String? txId}) async =>
      (await _call('supportOpen', {'category': category.code, 'message': message, 'txId': ?txId}))['threadId'] as String;

  @override
  Future<void> send(String threadId, String text) => _call('supportSend', {'threadId': threadId, 'text': text});

  @override
  Future<void> markRead(String threadId) async {
    try {
      await _db.doc('supportThreads/$threadId').update({'memberReadAtMs': DateTime.now().millisecondsSinceEpoch});
    } catch (_) {
      // Only the unread badge depends on this; it catches up next time.
    }
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, Object?> data) async {
    try {
      final callable = AppConfig.backendUrl.isEmpty ? _functions.httpsCallable(name) : _functions.httpsCallableFromUrl('${AppConfig.backendUrl}/$name');
      final res = (await callable.call<Object?>(data)).data;
      return res is Map ? Map<String, dynamic>.from(res) : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : <String, dynamic>{};
      final message = switch (e.code) {
        'unavailable' || 'deadline-exceeded' when details['reason'] == null => 'No connection to Konduct. Check your data and try again.',
        'internal' when details['reason'] == null => 'Something went wrong on our side. Try again.',
        _ => e.message ?? 'Something went wrong. Try again.',
      };
      throw ApiException(details['reason'] as String? ?? e.code, message, details: details);
    }
  }
}
