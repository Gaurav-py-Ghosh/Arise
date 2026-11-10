import 'package:flutter/widgets.dart';

import '../app/controller.dart';

/// Hands the controller down the tree; dependents rebuild when it notifies.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  /// Subscribes the caller to controller changes.
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the controller without subscribing (for callbacks).
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
