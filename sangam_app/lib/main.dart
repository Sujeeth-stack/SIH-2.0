import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'core/device_identity.dart';
import 'core/theme.dart';
import 'data/api.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The only thing that must happen before the first frame: know which device
  // this is. There is no login, so there is nothing else to wait for.
  final deviceId = await DeviceIdentity.ensure();
  final api = SangamApi(deviceId: deviceId);

  // Register silently. If the server is down the app still opens — the user
  // finds that out when they try to send something, not on a splash screen.
  unawaited(api.registerDevice());

  runApp(SangamApp(api: api));
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}

class SangamApp extends StatelessWidget {
  final SangamApi api;
  const SangamApp({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: HomeShell(api: api), // opens straight on the main page
    );
  }
}
