import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/tokens.dart';
import 'kit.dart';

/// Opens [url] inside the app instead of a browser. [closeWhen] sees every page before it loads;
/// returning true closes the screen and gives back that address (a checkout's return URL, say).
/// Links that aren't web pages (a bank app, the dialler) go to the phone. Returns null if the
/// person closed it themselves.
Future<Uri?> openWeb(BuildContext context, String url, {String? title, bool Function(Uri)? closeWhen}) => Navigator.of(context).push<Uri>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => WebScreen(url: url, title: title, closeWhen: closeWhen),
  ),
);

class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.url, this.title, this.closeWhen});
  final String url;
  final String? title;
  final bool Function(Uri)? closeWhen;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _web;
  late Uri _at = Uri.parse(widget.url);
  int _progress = 0;
  String? _pageTitle;
  bool _failed = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) {
            final uri = Uri.tryParse(r.url);
            if (uri == null) return NavigationDecision.prevent;
            if (widget.closeWhen?.call(uri) == true) {
              _close(uri);
              return NavigationDecision.prevent;
            }
            if (uri.scheme != 'https' && uri.scheme != 'http') {
              // Bank apps, USSD, mail: the phone knows how to open them.
              launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (u) => setState(() {
            _at = Uri.tryParse(u) ?? _at;
            _failed = false;
          }),
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (_) async {
            final t = await _web.getTitle();
            if (mounted) setState(() => _pageTitle = t);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(_at);
  }

  void _close([Uri? result]) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final secure = _at.scheme == 'https';
    final heading = (widget.title?.isNotEmpty ?? false) ? widget.title! : (_pageTitle?.isNotEmpty ?? false ? _pageTitle! : _at.host);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else {
          _close();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: K.ink,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      _HeadButton(icon: Icons.close_rounded, label: 'Close', onTap: _close),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              heading,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w800),
                            ),
                            Row(
                              children: [
                                Icon(secure ? Icons.lock_rounded : Icons.lock_open_rounded, size: 12, color: secure ? K.go : K.coral),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(_at.host, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.small(K.muteDark).copyWith(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _HeadButton(icon: Icons.refresh_rounded, label: 'Reload', onTap: () => _web.reload()),
                    ],
                  ),
                ),
                SizedBox(
                  height: 3,
                  child: AnimatedOpacity(
                    opacity: _progress < 100 ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: LinearProgressIndicator(value: _progress / 100, backgroundColor: Colors.transparent, color: K.yellow, minHeight: 3),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: _failed ? _Offline(onRetry: () => _web.reload()) : WebViewWidget(controller: _web),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadButton extends StatelessWidget {
  const _HeadButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: K.paper, size: 22),
      ),
    ),
  );
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: K.paper,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: K.mute),
            const SizedBox(height: 12),
            Text('This page didn\'t load', style: KText.h3(K.ink)),
            const SizedBox(height: 6),
            Text('Check your data or Wi-Fi, then try again.', textAlign: TextAlign.center, style: KText.body(K.mute)),
            const SizedBox(height: 18),
            SizedBox(
              width: 180,
              child: KButton(label: 'Try again', onTap: onRetry),
            ),
          ],
        ),
      ),
    ),
  );
}
