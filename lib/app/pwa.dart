/// The installed web app (PWA): installing it, and whether it already is. On phones running the
/// Android or iOS app this is a stub that does nothing.
library;

export 'pwa_stub.dart' if (dart.library.js_interop) 'pwa_web.dart';
