import 'package:flutter/material.dart' hide Text;

import '../../l10n/l10n.dart';
import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'home_screen.dart';
import 'transaction_screen.dart';
import '../../support/support_screens.dart';

/// Every fare and top-up, newest first.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.api});
  final RiderApi api;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late Stream<List<Activity>> _items = widget.api.activity(limit: 100);

  Future<void> _refresh() async {
    await refreshWallet(context, widget.api);
    if (mounted) setState(() => _items = widget.api.activity(limit: 100));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      trailing: SupportButton(api: widget.api.support),
      kicker: 'Activity',
      title: 'Your rides and top-ups',
      onRefresh: _refresh,
      child: StreamBuilder<List<Activity>>(
        stream: _items,
        builder: (_, s) {
          if (s.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Couldn\'t load your activity. Check your connection.', style: KText.body(p.subtle)),
            );
          }
          if (!s.hasData) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: K.yellowDeep)),
            );
          }
          final items = s.data!;
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Nothing yet. Your rides and top-ups will show up here.', style: KText.body(p.subtle)),
            );
          }
          String? lastDay;
          final children = <Widget>[];
          for (final a in items) {
            final day = _day(a.at);
            if (day != lastDay) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 4),
                  child: Text(day.toUpperCase(), style: KText.kicker(p.subtle)),
                ),
              );
              lastDay = day;
            }
            children.add(ActivityTile(a: a, onTap: () => openActivity(context, widget.api, a)));
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
        },
      ),
    );
  }

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  static String _day(DateTime t) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = DateTime(t.year, t.month, t.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${t.day} ${tr(_months[t.month - 1])}${t.year == n.year ? '' : ' ${t.year}'}';
  }
}
