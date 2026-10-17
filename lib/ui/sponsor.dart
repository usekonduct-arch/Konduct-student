import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/tokens.dart';

/// A sponsor's logo on a white tile, so any brand colour reads on any background.
class SponsorLogo extends StatelessWidget {
  const SponsorLogo({super.key, required this.url, this.size = 44});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.26), border: Border.all(color: K.line)),
      child: url.isEmpty
          ? Icon(Icons.campaign_rounded, color: K.ink, size: size * 0.5)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => Icon(Icons.campaign_rounded, color: K.ink, size: size * 0.5),
            ),
    );
  }
}

/// "This ride is on MTN": the sponsor's logo and offer, shown before the rider pays.
class SponsorBanner extends StatelessWidget {
  const SponsorBanner({super.key, required this.name, required this.logoUrl, required this.title, this.message = ''});
  final String name, logoUrl, title, message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          SponsorLogo(url: logoUrl, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This ride is on $name', style: KText.kicker(K.yellow)),
                const SizedBox(height: 4),
                Text(title, translate: false, style: KText.h3(K.paper)),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(message, translate: false, style: KText.small(K.muteDark)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Paid by MTN" with the logo: a small line for receipts and activity.
class PaidByLine extends StatelessWidget {
  const PaidByLine({super.key, required this.name, required this.logoUrl, required this.color});
  final String name, logoUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SponsorLogo(url: logoUrl, size: 24),
        const SizedBox(width: 8),
        Flexible(child: Text('Paid by $name', style: KText.small(color).copyWith(fontWeight: FontWeight.w700))),
      ],
    );
  }
}
