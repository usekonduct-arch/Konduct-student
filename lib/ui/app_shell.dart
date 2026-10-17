import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_info.dart';
import '../app/connection.dart';
import '../app/pwa.dart';
import '../app/version_check.dart';
import '../l10n/l10n.dart';
import '../l10n/text.dart';
import '../theme/tokens.dart';
import 'kit.dart';

/// Wraps every screen (MaterialApp.builder):
///  - an "Update Konduct" screen in place of the app when this build is too old (config/app),
///  - a floating note at the top when the phone has no connection, or a newer build is out,
///  - system text size honoured up to 1.3×, beyond which the money screens can't lay out.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget? child;

  static const maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: maxTextScale)),
      child: ListenableBuilder(
        listenable: VersionCheck.instance,
        builder: (context, _) {
          final v = VersionCheck.instance;
          if (v.mustUpdate) return UpdateScreen(url: v.updateUrl);
          return Stack(
            children: [
              ?child,
              const Positioned(left: 0, right: 0, top: 0, child: SafeArea(bottom: false, child: _StatusStrip())),
            ],
          );
        },
      ),
    );
  }
}

class _StatusStrip extends StatefulWidget {
  const _StatusStrip();
  @override
  State<_StatusStrip> createState() => _StatusStripState();
}

class _StatusStripState extends State<_StatusStrip> {
  static const _installKey = 'konduct.installHintDismissed';

  bool _updateDismissed = false;

  /// The web app in a browser tab offers to be installed until closed once; null while reading that.
  bool? _installDismissed = kIsWeb ? null : true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    SharedPreferences.getInstance().then((p) => p.getBool(_installKey) ?? false, onError: (_) => false).then((v) {
      if (mounted) setState(() => _installDismissed = v);
    });
  }

  void _dismissInstall() {
    setState(() => _installDismissed = true);
    SharedPreferences.getInstance().then((p) => p.setBool(_installKey, true)).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Connection.instance.online, VersionCheck.instance, Pwa.installable]),
      builder: (context, _) {
        final offline = Connection.instance.isOffline;
        final update = VersionCheck.instance.canUpdate && VersionCheck.instance.updateUrl != null && !_updateDismissed;
        // Chrome offers an install dialog; on an iPhone it's Share, then Add to Home Screen.
        final canPrompt = Pwa.installable.value;
        final install = _installDismissed == false && !Pwa.standalone && (canPrompt || Pwa.isIos);
        final Widget? pill = offline
            ? _Pill(
                key: const ValueKey('offline'),
                icon: Icons.wifi_off_rounded,
                color: K.coral,
                text: 'No connection. Turn on data or Wi-Fi to pay and see your balance.',
              )
            : update
            ? _Pill(
                key: const ValueKey('update'),
                icon: Icons.system_update_rounded,
                color: K.go,
                text: 'A new version of ${AppInfo.name} is ready.',
                action: 'Update',
                onAction: () => _open(VersionCheck.instance.updateUrl!),
                onClose: () => setState(() => _updateDismissed = true),
              )
            : install
            ? _Pill(
                key: const ValueKey('install'),
                icon: Icons.install_mobile_rounded,
                color: K.yellow,
                text: canPrompt ? 'Add Konduct to your home screen.' : 'Add Konduct to your Home Screen: tap Share, then Add to Home Screen.',
                action: canPrompt ? 'Install' : null,
                onAction: Pwa.install,
                onClose: _dismissInstall,
              )
            : null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(a), child: c),
          ),
          child: pill ?? const SizedBox.shrink(key: ValueKey('none')),
        );
      },
    );
  }
}

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.color, required this.text, this.action, this.onAction, this.onClose});
  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onAction, onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
    child: Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: K.ink,
        elevation: 6,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: KText.small(K.paper))),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(action!, style: KText.small(K.yellow).copyWith(fontWeight: FontWeight.w800)),
                ),
              if (onClose != null)
                IconButton(
                  tooltip: tr('Not now'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: K.muteDark, size: 18),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shown in place of the whole app when this build is no longer allowed.
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key, this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppInfo.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const KMark(size: 64),
                const SizedBox(height: 24),
                Text('Update ${AppInfo.name}', style: KText.title(p.text)),
                const SizedBox(height: 12),
                Text(
                  'This version is no longer supported. Update to keep paying and getting paid safely. Your money and account are safe.',
                  style: KText.body(p.subtle),
                ),
                const Spacer(),
                if (url != null) KButton(label: 'Update now', icon: Icons.system_update_rounded, onTap: () => _open(url!)),
                if (url == null) Text('Ask a Konduct agent at the park for the new version.', style: KText.body(p.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
