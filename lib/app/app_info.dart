import '../theme/tokens.dart';

/// Which app this is. Students pay fares here; the
/// driver app lives in its own repo (usekonduct-arch/Konduct-Driver).
abstract final class AppInfo {
  static const name = 'Konduct';
  /// The account role this app serves; the backend sets it as a custom claim.
  static const role = 'rider';
  static const palette = Palette.rider;
  static const dark = false;

  /// Links into the app: konduct://pay?code=AB12CD, https://konduct.com.ng/pay/AB12CD (AndroidManifest.xml).
  static const linkScheme = 'konduct';
  static const linkHosts = {'konduct.com.ng', 'www.konduct.com.ng'};

  /// Screens a link, shortcut or widget may open (the home screen's app: actions).
  static const linkScreens = {'pay', 'scan', 'topup', 'buses', 'activity', 'account', 'withdraw', 'invite'};

  /// Long-press shortcuts on the app icon: action, English title, Android drawable.
  static const shortcuts = [
    ('scan', 'Scan to pay', 'ic_shortcut_scan'),
    ('topup', 'Top up', 'ic_shortcut_topup'),
    ('buses', 'Buses now', 'ic_shortcut_bus'),
  ];
}

/// Backend settings. The region must match `REGION` in konduct-backend/functions/src/config.ts.
abstract final class AppConfig {
  static const functionsRegion = 'europe-west1';
  /// The Render server (konduct-backend/functions/src/server.ts), e.g. https://konduct-backend.onrender.com.
  /// Build with --dart-define=BACKEND_URL=...; empty means Cloud Functions in [functionsRegion].
  static const backendUrl = String.fromEnvironment('BACKEND_URL');
  static const campusId = 'uniosun';
  static const campusName = 'UNIOSUN';
  static const campusPlace = 'Osun State University';
}
