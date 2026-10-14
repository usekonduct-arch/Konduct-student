import '../theme/tokens.dart';

enum Flavor {
  rider,
  driver;

  bool get isRider => this == Flavor.rider;
  bool get isDriver => this == Flavor.driver;
  String get appName => isRider ? 'Konduct' : 'Konduct Driver';
  Palette get palette => isRider ? Palette.rider : Palette.driver;
  bool get dark => isDriver;
}

/// Backend settings. The region must match `REGION` in konduct-backend/functions/src/config.ts.
abstract final class AppConfig {
  static const functionsRegion = 'europe-west1';
  static const campusId = 'uniosun';
  static const campusName = 'UNIOSUN';
  static const campusPlace = 'Osun State University';
}
