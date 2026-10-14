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
import 'flavor.dart';

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final options = firebaseOptionsFor(flavor);
  final AuthRepository repo;
  if (options != null) {
    await Firebase.initializeApp(options: options);
    repo = FirebaseAuthRepository();
  } else {
    repo = DemoAuthRepository();
  }
  runApp(KonductApp(flavor: flavor, auth: AuthController(repo, flavor)));
}

class KonductApp extends StatelessWidget {
  const KonductApp({super.key, required this.flavor, required this.auth});
  final Flavor flavor;
  final AuthController auth;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: flavor.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(flavor.palette, dark: flavor.dark),
        home: AuthGate(auth: auth),
      );
}
