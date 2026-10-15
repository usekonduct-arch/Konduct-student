import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_repository.dart';
import '../auth/demo_auth_repository.dart';
import '../auth/firebase_auth_repository.dart';
import '../firebase/firebase_options.dart';
import '../theme/tokens.dart';
import '../wallet/demo_rider_api.dart';
import '../wallet/firebase_rider_api.dart';
import '../wallet/rider_api.dart';
import '../l10n/l10n.dart';
import '../ui/app_shell.dart';
import 'app_info.dart';
import 'connection.dart';
import 'home_widget_sync.dart';
import 'intents.dart';
import 'version_check.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // The saved language, before the first frame, so nothing flashes in English first.
  await L10n.instance.load();

  final options = firebaseOptions();
  final AuthRepository repo;
  final RiderApi api;
  if (options != null) {
    await Firebase.initializeApp(options: options);
    _reportCrashes();
    repo = FirebaseAuthRepository();
    api = FirebaseRiderApi();
  } else {
    repo = DemoAuthRepository();
    api = DemoRiderApi();
  }
  unawaited(Connection.instance.start());
  unawaited(VersionCheck.instance.start(live: options != null));
  unawaited(AppIntents.instance.start());
  // Push notifications follow the app's language.
  L10n.instance.onChanged((l) => api.messages.setLanguage(l.code));
  L10n.instance.onChanged((_) => HomeWidgetSync.refresh());
  runApp(KonductApp(auth: AuthController(repo), api: api));
}

/// Crashes and uncaught errors go to Firebase Crashlytics (free on the Spark plan), so problems on
/// riders' and drivers' phones show up in the Firebase console. Off in debug builds.
void _reportCrashes() {
  final c = FirebaseCrashlytics.instance;
  unawaited(c.setCrashlyticsCollectionEnabled(!kDebugMode));
  FlutterError.onError = c.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(c.recordError(error, stack, fatal: true));
    return true;
  };
}

class KonductApp extends StatelessWidget {
  const KonductApp({super.key, required this.auth, required this.api});
  final AuthController auth;
  final RiderApi api;

  @override
  Widget build(BuildContext context) => L10nScope(
        child: MaterialApp(
          title: AppInfo.name,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(AppInfo.palette, dark: AppInfo.dark),
          builder: (context, child) => AppShell(child: child),
          home: AuthGate(auth: auth, api: api),
        ),
      );
}
