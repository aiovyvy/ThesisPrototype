import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/login/login_screen.dart';
import '../screens/research/research_demo_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/welcome/welcome_screen.dart';
import '../services/research_demo_client.dart';
import 'app_navigator.dart';
import 'main_shell.dart';
import 'route_session.dart';

/// Only non-sensitive destinations enter the URL. No patient IDs or input state.
class WebRouteParser extends RouteInformationParser<String> {
  static const paths = {'/', '/login', '/dashboard', '/patients', '/profile', '/settings', '/research-demonstration'};

  static const researchPath = '/research-demonstration';
  static String researchLocation(String id) => '$researchPath/$id';
  static bool isResearch(String location) =>
      location.startsWith('$researchPath/') &&
      ResearchDemoClient.exampleIds.contains(location.substring(researchPath.length + 1));
  static String normalize(String path) {
    if (path == researchPath) return researchLocation('R1');
    if (isResearch(path)) return path;
    if (path.startsWith('$researchPath/')) return researchLocation('R1');
    return paths.contains(path) ? path : '/';
  }

  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(normalize(routeInformation.uri.path));

  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri(path: normalize(configuration)));
}

/// A page refresh deliberately loses demo access and all repository state.
/// Research URLs carry only a public fixed-example ID and need no session.
/// Protected URLs still require sign-in after refresh. Back/Forward never grants
/// access or restores logged-out records.
class WebRouter extends RouterDelegate<String> with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  WebRouter({this.researchClient}) {
    AppNavigator.currentTab.addListener(_tabChanged);
  }
  final ResearchDemoClient? researchClient;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  String _location = '/';
  bool _signedIn = false;
  bool _applyingTab = false;
  int _sessionEpoch = 0;

  bool get signedIn => _signedIn;
  static bool guarded(String path) => path != '/' && path != '/login' && !WebRouteParser.isResearch(path);

  @override
  String get currentConfiguration => _location;

  void go(String path) {
    _setLocation(WebRouteParser.normalize(path));
    notifyListeners();
  }

  void signIn() {
    _signedIn = true;
    _sessionEpoch++;
    _setLocation(guarded(_location) ? _location : '/dashboard');
    notifyListeners();
  }

  void signOut() {
    _signedIn = false;
    _sessionEpoch++;
    _setLocation('/login');
    notifyListeners();
  }

  void _setLocation(String path) {
    _location = path;
    _applyingTab = true;
    AppNavigator.currentTab.value = switch (path) {
      '/patients' => ShellTab.patients,
      '/profile' => ShellTab.profile,
      '/dashboard' => ShellTab.home,
      _ => AppNavigator.currentTab.value,
    };
    _applyingTab = false;
  }

  void _tabChanged() {
    if (!_signedIn || _applyingTab) return;
    go(switch (AppNavigator.currentTab.value) {
      ShellTab.home => '/dashboard',
      ShellTab.patients => '/patients',
      ShellTab.profile => '/profile',
    });
  }

  @override
  Future<void> setNewRoutePath(String configuration) {
    _setLocation(WebRouteParser.normalize(configuration));
    notifyListeners();
    return SynchronousFuture(null);
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _signedIn && guarded(_location);
    final research = WebRouteParser.isResearch(_location);
    return RouteSession(
      go: go,
      signIn: signIn,
      signOut: signOut,
      child: Navigator(
        key: navigatorKey,
        pages: [
          // The public page has no private shell or Settings underneath it.
          if (research)
            MaterialPage<void>(
                key: const ValueKey('public-research'),
                name: _location,
                child: ResearchDemoScreen(
                  client: researchClient,
                  exampleId: _location.split('/').last,
                  onExampleSelected: (id) => go(WebRouteParser.researchLocation(id)),
                  onBack: () => go(_signedIn ? '/settings' : '/'),
                ))
          else if (!allowed)
            MaterialPage<void>(
                key: ValueKey('gate-$_sessionEpoch-${_location == '/' ? 'intro' : 'login'}'),
                name: _location,
                child: _location == '/' ? const WelcomeScreen() : const LoginScreen())
          else ...[
            MaterialPage<void>(key: ValueKey('shell-$_sessionEpoch'), name: '/dashboard', child: const MainShell()),
            if (_location == '/settings')
              const MaterialPage<void>(key: ValueKey('settings'), name: '/settings', child: SettingsScreen()),
          ],
        ],
        onDidRemovePage: (page) {
          if (page.name != _location) return;
          if (_location == '/settings') {
            go('/dashboard');
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    AppNavigator.currentTab.removeListener(_tabChanged);
    super.dispose();
  }
}
