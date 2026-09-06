import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'core/device_identity.dart';
import 'core/server_store.dart';
import 'core/theme.dart';
import 'data/api.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The only things that must be known before the first frame: which device
  // this is, and which server it talks to. There is no login, so there is
  // nothing else to wait for.
  final deviceId = await DeviceIdentity.ensure();
  final baseUrl = await ServerStore.load();

  runApp(SangamApp(deviceId: deviceId, initialBaseUrl: baseUrl));
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}

class SangamApp extends StatefulWidget {
  final String deviceId;
  final String initialBaseUrl;

  /// Injected by tests so the widget tree can be driven without real network.
  final SangamApi? apiOverride;

  const SangamApp({
    super.key,
    required this.deviceId,
    required this.initialBaseUrl,
    this.apiOverride,
  });

  @override
  State<SangamApp> createState() => _SangamAppState();
}

class _SangamAppState extends State<SangamApp> {
  late String _baseUrl = widget.initialBaseUrl;
  late SangamApi _api = widget.apiOverride ??
      SangamApi(deviceId: widget.deviceId, baseUrl: _baseUrl);

  @override
  void initState() {
    super.initState();
    // Register silently. If the server is down the app still opens — the user
    // finds that out when they try to send something, not on a splash screen.
    unawaited(_api.registerDevice());
  }

  /// Point the whole app at a different server. Everything below is rebuilt
  /// from scratch (see the ValueKey) so no screen keeps data fetched from the
  /// old one.
  void _useServer(String url) {
    final next = ServerStore.normalise(url);
    if (next == _baseUrl) return;
    setState(() {
      _baseUrl = next;
      _api = SangamApi(deviceId: widget.deviceId, baseUrl: next);
    });
    unawaited(_api.registerDevice());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: HomeShell(
        key: ValueKey(_baseUrl),
        api: _api,
        onServerChanged: _useServer,
      ),
    );
  }
}
