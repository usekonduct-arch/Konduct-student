import 'package:flutter/material.dart';

/// What a support conversation is about (backend SUPPORT_CATEGORIES).
enum SupportCategory {
  complaint('complaint', 'A complaint', 'About a driver, a rider or a ride', Icons.report_rounded),
  payment('payment', 'Payment or wallet', 'A charge, top-up, payout or refund', Icons.account_balance_wallet_rounded),
  account('account', 'My account', 'Password, PIN, locked account or details', Icons.lock_reset_rounded),
  app('app', 'The app isn\'t working', 'Something broken or confusing', Icons.bug_report_rounded),
  other('other', 'Something else', 'Questions or ideas', Icons.chat_bubble_rounded);

  const SupportCategory(this.code, this.label, this.hint, this.icon);
  final String code, label, hint;
  final IconData icon;

  static SupportCategory of(String? code) => values.firstWhere((c) => c.code == code, orElse: () => other);
}

/// supportThreads/{id}: one conversation with Konduct staff.
class SupportThread {
  const SupportThread({
    required this.id,
    required this.category,
    required this.open,
    required this.lastText,
    required this.lastFromStaff,
    required this.lastAt,
    required this.readAt,
    this.txId,
  });

  final String id, lastText;
  final SupportCategory category;
  final bool open, lastFromStaff;
  final DateTime lastAt, readAt;
  final String? txId;

  /// Staff replied after the member last looked.
  bool get unread => lastFromStaff && lastAt.isAfter(readAt);
}

/// supportThreads/{id}/messages/{id}
class SupportMessage {
  const SupportMessage({required this.id, required this.fromStaff, required this.authorName, required this.text, required this.at});
  final String id, authorName, text;
  final bool fromStaff;
  final DateTime at;
}

/// Chat with Konduct staff. Reads are live; sending goes through the backend.
abstract class SupportApi {
  /// This person's conversations, newest activity first.
  Stream<List<SupportThread>> threads();

  /// One conversation's messages, oldest first.
  Stream<List<SupportMessage>> messages(String threadId);

  /// Starts a conversation. Returns its id.
  Future<String> open({required SupportCategory category, required String message, String? txId});

  Future<void> send(String threadId, String text);

  /// The member has seen the conversation up to now.
  Future<void> markRead(String threadId);

  /// Conversations with a staff reply not seen yet.
  Stream<int> unread() => threads().map((list) => list.where((t) => t.unread).length);
}
