import 'package:firebase_core/firebase_core.dart';
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
import 'app_info.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final options = firebaseOptions();
  final AuthRepository repo;
  final RiderApi api;
  if (options != null) {
    await Firebase.initializeApp(options: options);
    repo = FirebaseAuthRepository();
    api = FirebaseRiderApi();
  } else {
    repo = DemoAuthRepository();
    api = DemoRiderApi();
  }
  runApp(KonductApp(auth: AuthController(repo), api: api));
}

class KonductApp extends StatelessWidget {
  const KonductApp({super.key, required this.auth, required this.api});
  final AuthController auth;
  final RiderApi api;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppInfo.palette, dark: AppInfo.dark),
        home: AuthGate(auth: auth, api: api),
      );
}
