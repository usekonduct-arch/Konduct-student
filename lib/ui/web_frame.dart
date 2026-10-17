import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The web app on a wide screen (a laptop browser) keeps its phone shape: a phone-wide column in
/// the middle, told it is the whole screen, so every page lays out exactly as on a phone. Phones
/// and narrow windows get the full width, like the Android app.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});
  final Widget child;

  static const maxWidth = 460.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (!kIsWeb || mq.size.width <= maxWidth) return child;
    final size = Size(maxWidth, mq.size.height);
    return ColoredBox(
      color: K.ink,
      child: Center(
        child: DecoratedBox(
          decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 40)]),
          child: ClipRect(
            child: SizedBox.fromSize(
              size: size,
              child: MediaQuery(data: mq.copyWith(size: size), child: child),
            ),
          ),
        ),
      ),
    );
  }
}
