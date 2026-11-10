import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/controller.dart';
import 'core/game_config.dart';
import 'data/store.dart';
import 'system/bridge.dart';
import 'system/llm.dart';
import 'system/secrets.dart';
import 'ui/scope.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Sys.panel,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final (store, key) = await (Store.open(), Secrets.geminiKey()).wait;
  final model = await store.get('model') ?? GameConfig.defaultModel;
  final controller = AppController(
    store: store,
    bridge: AndroidBridge(),
    llm: key == null ? null : GeminiLlm(apiKey: key, model: model),
  );
  runApp(AriseApp(controller: controller));
  await controller.init();
}

class AriseApp extends StatelessWidget {
  const AriseApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'Arise',
        debugShowCheckedModeBanner: false,
        theme: Sys.theme(),
        themeMode: ThemeMode.dark,
        scrollBehavior: const SysScroll(),
        home: _Gate(controller: controller),
      ),
    );
  }
}

/// Plain boot screen until the controller has loaded.
class _Gate extends StatelessWidget {
  const _Gate({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    // Subscribes to the controller so the gate opens once it is ready.
    final ready = AppScope.of(context).ready;
    if (ready) return Shell(controller: controller);
    return const Scaffold(
      body: Center(
        child: Text(
          'INITIALISING SYSTEM...',
          style: TextStyle(
            fontFamily: Sys.font,
            fontSize: 12,
            letterSpacing: 3,
            color: Sys.dim,
          ),
        ),
      ),
    );
  }
}
