import 'package:flutter/widgets.dart';

/// Browser navigation bridge. Holds callbacks only; nothing is persisted.
class RouteSession extends InheritedWidget {
  const RouteSession({super.key, required this.go, required this.signIn, required this.signOut, required super.child});
  final void Function(String) go;
  final VoidCallback signIn;
  final VoidCallback signOut;

  static RouteSession? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RouteSession>();

  @override
  bool updateShouldNotify(RouteSession oldWidget) => false;
}
