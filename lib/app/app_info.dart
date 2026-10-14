import '../theme/tokens.dart';

/// Which app this is. Students pay fares here; the
/// driver app lives in its own repo (usekonduct-arch/Konduct-Driver).
abstract final class AppInfo {
  static const name = 'Konduct';
  /// The account role this app serves; the backend sets it as a custom claim.
  static const role = 'rider';
  static const palette = Palette.rider;
  static const dark = false;
}

/// Backend settings. The region must match `REGION` in konduct-backend/functions/src/config.ts.
abstract final class AppConfig {
  static const functionsRegion = 'europe-west1';
  static const campusId = 'uniosun';
  static const campusName = 'UNIOSUN';
  static const campusPlace = 'Osun State University';
}
