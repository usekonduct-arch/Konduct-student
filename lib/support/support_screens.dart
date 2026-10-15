import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/kit.dart';
import '../wallet/models.dart' show ApiException;
import '../wallet/wallet_ui.dart';
import 'support_api.dart';

/// The support icon for screen headers, with a dot when staff have replied.
class SupportButton extends StatefulWidget {
  const SupportButton({super.key, required this.api, this.txId});
  final SupportApi api;

  /// Opened from a receipt: a new conversation is about this payment.
  final String? txId;

  @override
  State<SupportButton> createState() => _SupportButtonState();
}

class _SupportButtonState extends State<SupportButton> {
  late final _unread = widget.api.unread();

  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
    stream: _unread,
    builder: (_, s) {
      final n = s.data ?? 0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          RoundIconButton(
            icon: Icons.support_agent_rounded,
            tooltip: n == 0 ? 'Help and support' : 'Help and support, $n new ${n == 1 ? 'reply' : 'replies'}',
            onTap: () => pushScreen(context, SupportScreen(api: widget.api, txId: widget.txId)),
          ),
          if (n > 0)
            Positioned(
              right: -2,
              top: -2,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(color: K.coral, borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: Text('$n', style: KText.small(Colors.white).copyWith(fontSize: 11)),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// The member's conversations with Konduct staff, and "New message".
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.api, this.txId});
  final SupportApi api;
  final String? txId;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final _threads = widget.api.threads();

  void _new() => pushScreen(
    context,
    NewSupportScreen(api: widget.api, txId: widget.txId, category: widget.txId == null ? null : SupportCategory.payment),
  );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      kicker: 'Support',
      title: 'Help & support',
      bottom: KButton(label: 'New message', icon: Icons.add_rounded, onTap: _new),
      child: StreamBuilder<List<SupportThread>>(
        stream: _threads,
        builder: (_, s) {
          if (s.hasError) return _Note(text: 'Couldn\'t load your messages. Check your connection and try again.', icon: Icons.cloud_off_rounded);
          if (!s.hasData) {
            return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: K.yellowDeep)));
          }
          final threads = s.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Note(
                icon: Icons.support_agent_rounded,
                text: 'Message the Konduct team about anything: a complaint, a payment, your account or the app. We reply here and you\'ll get a notification.',
              ),
              const SizedBox(height: 18),
              if (threads.isNotEmpty) ...[Text('YOUR CONVERSATIONS', style: KText.kicker(p.subtle)), const SizedBox(height: 8)],
              for (final t in threads)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    scale: 0.98,
                    onTap: () => pushScreen(context, SupportThreadScreen(api: widget.api, thread: t)),
                    child: Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(t.category.icon, color: p.subtle),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(t.category.label, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800)),
                                    ),
                                    Text(whenText(t.lastAt), style: KText.small(p.subtle).copyWith(fontSize: 11.5)),
                                  ],
                                ),
                                Text(
                                  '${t.lastFromStaff ? 'Konduct: ' : 'You: '}${t.lastText}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: KText.small(t.unread ? p.text : p.subtle).copyWith(fontWeight: t.unread ? FontWeight.w800 : null),
                                ),
                                if (!t.open) ...[const SizedBox(height: 6), const Tag('Solved', color: K.go)],
                              ],
                            ),
                          ),
                          if (t.unread) ...[
                            const SizedBox(width: 10),
                            Semantics(
                              label: 'New reply',
                              child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: K.coral, shape: BoxShape.circle)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pick what it's about, write the first message.
class NewSupportScreen extends StatefulWidget {
  const NewSupportScreen({super.key, required this.api, this.txId, this.category});
  final SupportApi api;
  final String? txId;
  final SupportCategory? category;
  @override
  State<NewSupportScreen> createState() => _NewSupportScreenState();
}

class _NewSupportScreenState extends State<NewSupportScreen> {
  late SupportCategory? _category = widget.category;
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.api.open(category: _category!, message: _message.text.trim(), txId: widget.txId);
      if (!mounted) return;
      final thread = SupportThread(
        id: id,
        category: _category!,
        open: true,
        lastText: _message.text.trim(),
        lastFromStaff: false,
        lastAt: DateTime.now(),
        readAt: DateTime.now(),
        txId: widget.txId,
      );
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SupportThreadScreen(api: widget.api, thread: thread)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ready = _category != null && _message.text.trim().isNotEmpty;
    return PageFrame(
      kicker: 'Support',
      title: 'How can we help?',
      bottom: KButton(label: 'Send', icon: Icons.send_rounded, loading: _busy, onTap: ready ? _send : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.txId != null) ...[
            const Tag('About this payment', icon: Icons.receipt_long_rounded),
            const SizedBox(height: 14),
          ],
          for (final c in SupportCategory.values)
            Semantics(
              selected: _category == c,
              button: true,
              child: Pressable(
                scale: 0.98,
                onTap: () => setState(() => _category = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _category == c ? K.yellow.withValues(alpha: 0.2) : p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _category == c ? K.yellowDeep : p.border, width: _category == c ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(c.icon, color: p.text),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.label, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
                            Text(c.hint, style: KText.small(p.subtle)),
                          ],
                        ),
                      ),
                      if (_category == c) const Icon(Icons.check_circle_rounded, color: K.yellowDeep),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          _Composer(controller: _message, hint: 'Tell us what happened: when, where, the plate number if you have it.', minLines: 4),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: KText.small(K.coral))),
        ],
      ),
    );
  }
}

/// One conversation: the messages and a box to reply.
class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({super.key, required this.api, required this.thread});
  final SupportApi api;
  final SupportThread thread;
  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  late final _messages = widget.api.messages(widget.thread.id);
  final _text = TextEditingController();
  bool _busy = false;
  DateTime? _readUpTo;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    widget.api.markRead(widget.thread.id);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.api.send(widget.thread.id, text);
      _text.clear();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A staff reply arrived while the conversation is open: it counts as read.
  void _seen(List<SupportMessage> list) {
    final last = list.lastWhere((m) => m.fromStaff, orElse: () => SupportMessage(id: '', fromStaff: true, authorName: '', text: '', at: DateTime(2000)));
    if (_readUpTo == null || last.at.isAfter(_readUpTo!)) {
      _readUpTo = last.at;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.api.markRead(widget.thread.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      kicker: 'Support',
      title: widget.thread.category.label,
      scroll: false,
      bottom: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _Composer(controller: _text, hint: 'Write a message', minLines: 1)),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Send message',
            child: Pressable(
              onTap: _busy || _text.text.trim().isEmpty ? null : _send,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _text.text.trim().isEmpty ? 0.4 : 1,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: K.yellow, shape: BoxShape.circle),
                  child: _busy
                      ? const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2.4, color: K.ink))
                      : const Icon(Icons.send_rounded, color: K.ink),
                ),
              ),
            ),
          ),
        ],
      ),
      child: StreamBuilder<List<SupportMessage>>(
        stream: _messages,
        builder: (_, s) {
          if (s.hasError) return _Note(text: 'Couldn\'t load this conversation. Check your connection.', icon: Icons.cloud_off_rounded);
          if (!s.hasData) return const Center(child: CircularProgressIndicator(color: K.yellowDeep));
          final list = s.data!;
          _seen(list);
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: list.length + 1,
            itemBuilder: (_, i) {
              if (i == list.length) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Konduct staff usually reply within a few hours, 7am to 9pm. You\'ll get a notification.',
                    textAlign: TextAlign.center,
                    style: KText.small(p.subtle),
                  ),
                );
              }
              return _Bubble(list[list.length - 1 - i]);
            },
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m);
  final SupportMessage m;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final mine = !m.fromStaff;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine ? K.yellow : p.surface,
            border: mine ? null : Border.all(color: p.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  m.authorName.isEmpty ? 'Konduct support' : 'Konduct support · ${m.authorName}',
                  style: KText.small(p.subtle).copyWith(fontSize: 11.5),
                ),
              Text(m.text, style: KText.body(mine ? K.ink : p.text)),
              const SizedBox(height: 2),
              Text(whenText(m.at), style: KText.small(mine ? K.ink.withValues(alpha: 0.6) : p.subtle).copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.hint, required this.minLines});
  final TextEditingController controller;
  final String hint;
  final int minLines;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.border));
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: 6,
      maxLength: 1000,
      textCapitalization: TextCapitalization.sentences,
      style: KText.body(p.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: KText.body(p.subtle),
        counterText: '',
        filled: true,
        fillColor: p.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: K.yellowDeep, width: 2)),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      child: Row(
        children: [
          Icon(icon, color: p.subtle),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: KText.small(p.subtle))),
        ],
      ),
    );
  }
}
