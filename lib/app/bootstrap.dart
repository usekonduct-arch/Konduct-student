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
import 'app_info.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final options = firebaseOptions();
  final AuthRepository repo;
  if (options != null) {
    await Firebase.initializeApp(options: options);
    repo = FirebaseAuthRepository();
  } else {
    repo = DemoAuthRepository();
  }
  runApp(KonductApp(auth: AuthController(repo)));
}

class KonductApp extends StatelessWidget {
  const KonductApp({super.key, required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppInfo.palette, dark: AppInfo.dark),
        home: AuthGate(auth: auth),
      );
}
