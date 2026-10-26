import 'package:flutter/widgets.dart';

/// Generic URL only. Implementations must never include patient/input data.
abstract interface class TemporaryWebPage {
  String get temporaryWebLocation;
}

/// A safe, data-independent page that can be rebuilt from its URL alone.
abstract interface class RestorableWebPage {
  String get restorableWebLocation;
  bool get requiresDemoAccess;
}

/// Browser navigation bridge. Holds callbacks only; nothing is persisted.
class RouteSession extends InheritedWidget {
  const RouteSession(
      {super.key,
      required this.go,
      required this.signIn,
      required this.signOut,
      this.hasDemoAccess,
      required super.child});
  final void Function(String) go;
  final VoidCallback signIn;
  final VoidCallback signOut;
  final bool Function()? hasDemoAccess;

  static RouteSession? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RouteSession>();

  @override
  bool updateShouldNotify(RouteSession oldWidget) => false;
}
