import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';

const _labels = ['Poor', 'Not great', 'Okay', 'Good', 'Excellent'];

/// Asks the rider to rate the driver of [fare]. Returns true once the rating is sent.
Future<bool> rateRide(BuildContext context, RiderApi api, Activity fare) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RateSheet(api: api, fare: fare),
  );
  if (done == true && context.mounted) showSnack(context, 'Thanks for rating ${fare.driverLabel}.');
  return done == true;
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.api, required this.fare});
  final RiderApi api;
  final Activity fare;
  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.rateDriver(txId: widget.fare.id, stars: _stars, comment: _comment.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Already rated (another phone, a double tap): that's still a rating.
      if (e.reason == 'already_rated') return Navigator.of(context).pop(true);
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final trip = widget.fare.tripRoute;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 44, height: 5, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 18),
              Text('How was your ride with ${widget.fare.driverLabel}?', style: KText.h3(p.text)),
              const SizedBox(height: 4),
              Text(
                [if (trip != null) trip.label, if (widget.fare.plate.isNotEmpty) widget.fare.plate, whenText(widget.fare.at)].join(' · '),
                style: KText.small(p.subtle),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Semantics(
                      button: true,
                      selected: _stars == i,
                      label: tr('$i ${i == 1 ? 'star' : 'stars'}, ${_labels[i - 1]}'),
                      excludeSemantics: true,
                      child: Pressable(
                        scale: 0.85,
                        onTap: _busy
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() => _stars = i);
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: Icon(
                              i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                              key: ValueKey(i <= _stars),
                              size: 48,
                              color: i <= _stars ? K.yellowDeep : p.border,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(_stars == 0 ? 'Tap a star' : _labels[_stars - 1], style: KText.body(_stars == 0 ? p.subtle : p.text).copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _comment,
                maxLength: 300,
                maxLines: 3,
                minLines: 2,
                style: KText.body(p.text),
                decoration: InputDecoration(
                  hintText: 'Tell Konduct more (optional). The driver won\'t see your name.',
                  hintStyle: KText.body(p.subtle),
                  filled: true,
                  fillColor: p.field,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: K.yellowDeep, width: 2)),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: KText.small(K.coral)),
                ),
              KButton(label: 'Send rating', loading: _busy, onTap: _stars == 0 ? null : _send),
            ],
          ),
        ),
      ),
    );
  }
}

/// On a receipt: rate the driver once the trip should be over, or show the rating already given.
class RideRatingCard extends StatefulWidget {
  const RideRatingCard({super.key, required this.api, required this.txId});
  final RiderApi api;
  final String txId;
  @override
  State<RideRatingCard> createState() => _RideRatingCardState();
}

class _RideRatingCardState extends State<RideRatingCard> {
  late final _fare = widget.api.fare(widget.txId);
  // "Rate from 09:42" turns into the stars when the time comes.
  late final Timer _tick = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return StreamBuilder<Activity?>(
      stream: _fare,
      builder: (_, s) {
        final f = s.data;
        if (f == null || f.status != 'completed') return const SizedBox.shrink();
        final now = DateTime.now();
        final Widget body;
        if (f.rating != null) {
          body = Row(
            children: [
              for (var i = 1; i <= 5; i++) Icon(i <= f.rating! ? Icons.star_rounded : Icons.star_outline_rounded, size: 22, color: i <= f.rating! ? K.yellowDeep : p.border),
              const SizedBox(width: 10),
              Expanded(child: Text('You rated ${f.driverLabel}. Thank you.', style: KText.small(p.text))),
            ],
          );
        } else if (f.canRateAt(now)) {
          body = Row(
            children: [
              const Icon(Icons.star_rounded, color: K.yellowDeep),
              const SizedBox(width: 10),
              Expanded(child: Text('How was your ride with ${f.driverLabel}?', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Pressable(
                onTap: () => rateRide(context, widget.api, f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(20)),
                  child: Text('Rate', style: KText.body(K.ink).copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          );
        } else if (f.rateFrom != null && now.isBefore(f.rateFrom!)) {
          final at = f.rateFrom!;
          body = Row(
            children: [
              Icon(Icons.schedule_rounded, color: p.subtle),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You can rate ${f.driverLabel} once you arrive, from ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}.',
                  style: KText.small(p.subtle),
                ),
              ),
            ],
          );
        } else {
          return const SizedBox.shrink();
        }
        return Padding(padding: const EdgeInsets.only(bottom: 14), child: Panel(child: body));
      },
    );
  }
}
