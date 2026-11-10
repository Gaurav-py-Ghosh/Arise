import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/controller.dart';
import 'core/game_config.dart';
import 'data/store.dart';
import 'system/bridge.dart';
import 'system/llm.dart';
import 'system/secrets.dart';
import 'ui/boot_screen.dart';
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
  const AriseApp({super.key, required this.controller, this.boot = true});

  final AppController controller;

  /// Shows the animated boot screen first. Tests turn it off.
  final bool boot;

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
        home: _Gate(controller: controller, boot: boot),
      ),
    );
  }
}

/// Boot screen, then the app once the controller is ready.
class _Gate extends StatefulWidget {
  const _Gate({required this.controller, required this.boot});

  final AppController controller;
  final bool boot;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  late bool _booting = widget.boot;

  @override
  Widget build(BuildContext context) {
    // Subscribes to the controller so the gate opens once it is ready.
    final ready = AppScope.of(context).ready;
    final Widget child;
    if (_booting || !ready) {
      child = widget.boot
          ? BootScreen(
              key: const ValueKey('boot'),
              controller: widget.controller,
              onDone: () => setState(() => _booting = false),
            )
          : const Scaffold(key: ValueKey('wait'), backgroundColor: Sys.bg);
    } else {
      child = Shell(key: const ValueKey('shell'), controller: widget.controller);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: child,
    );
  }
}
