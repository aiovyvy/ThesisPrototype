import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/login/login_screen.dart';
import '../screens/assessment/assessment_input_screen.dart';
import '../screens/research/research_demo_screen.dart';
import '../screens/research/research_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/welcome/welcome_screen.dart';
import '../screens/welcome/onboarding_screen.dart';
import '../services/research_demo_client.dart';
import '../core/theme/app_colors.dart';
import 'app_navigator.dart';
import 'demo_mode_storage.dart';
import 'demo_mode_storage_stub.dart' if (dart.library.js_interop) 'demo_mode_storage_web.dart' as platform;
import 'main_shell.dart';
import 'route_session.dart';

/// Only non-sensitive destinations enter the URL. No patient IDs or input state.
class WebRouteParser extends RouteInformationParser<String> {
  static const temporaryPaths = {'/processing', '/result', '/explanation', '/patient-details'};
  static const publicPaths = {'/', '/login', '/onboarding'};
  static const safeProtectedPaths = {
    '/dashboard',
    '/patients',
    '/profile',
    '/settings',
    '/how-aiovy-works',
    '/assessment'
  };
  static const paths = {...publicPaths, ...safeProtectedPaths, '/research-demonstration', ...temporaryPaths};

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

/// A non-secret, tab-scoped DEMO-ONLY marker can restore UI access, never data.
/// This is deliberately not authentication. Research remains public.
class WebRouter extends RouterDelegate<String> with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  WebRouter({this.researchClient, DemoSession? demoSession, this.onClearSession})
      : _demoSession = demoSession ?? DemoSession(platform.createDemoModeStorage()) {
    _signedIn = _demoSession.canRestore;
    _refreshEnabled = _signedIn;
    if (_signedIn) _notice = restoredNotice;
    _observer = _StackObserver(_stackChanged);
    final storage = _demoSession.storage;
    if (storage is DemoModeEvents) {
      _stopWatching = (storage as DemoModeEvents).watch(_validateStoredMode);
    }
    AppNavigator.currentTab.addListener(_tabChanged);
  }
  final ResearchDemoClient? researchClient;
  final VoidCallback? onClearSession;
  final DemoSession _demoSession;
  late final _StackObserver _observer;
  VoidCallback? _stopWatching;
  static const restoredNotice = 'DEMO-ONLY access restored. Session records and assessments were not restored.';
  static const storageUnavailableNotice =
      'Browser session storage is unavailable. DEMO-ONLY access will be lost on refresh.';
  static const storageClearFailureNotice = 'Demo access ended here, but browser storage could not be cleared. '
      'Close this tab and clear this site’s session storage before using it again.';
  static const blankAssessmentNotice =
      'Blank new assessment. Any previous unsaved draft and patient selection were not restored.';
  static const patientUnavailableNotice = 'Patient selection unavailable. Choose a record from Patients. '
      'Session records lost on refresh are not recreated.';
  static const lostStateNotice = 'This page needs temporary assessment or patient state that is no longer available. '
      'You are back on Dashboard. No assessment or explanation was restored or recreated. Start a new synthetic assessment if needed.';
  static const lostStateGateNotice = 'This page needs temporary patient or assessment state that cannot be restored. '
      'Start a DEMO-ONLY session to continue on Dashboard.';

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  String _location = '/';
  bool _signedIn = false;
  bool _refreshEnabled = false;
  String? _overlayLocation;
  String? _notice;
  bool _applyingTab = false;
  int _sessionEpoch = 0;

  bool get signedIn => _signedIn;
  static bool guarded(String path) => !WebRouteParser.publicPaths.contains(path) && !WebRouteParser.isResearch(path);

  @override
  String get currentConfiguration => _overlayLocation ?? _location;

  void go(String path) {
    _validateStoredMode();
    if (_overlayLocation != null) _sessionEpoch++;
    _overlayLocation = null;
    _setLocation(WebRouteParser.normalize(path));
    notifyListeners();
  }

  void signIn() {
    final lostState = _notice == lostStateGateNotice;
    final patientUnavailable = _notice == patientUnavailableNotice;
    _signedIn = true;
    _refreshEnabled = _demoSession.enable();
    _notice = _refreshEnabled ? null : storageUnavailableNotice;
    if (_refreshEnabled && lostState) _notice = lostStateNotice;
    if (_refreshEnabled && patientUnavailable) _notice = patientUnavailableNotice;
    _sessionEpoch++;
    _setLocation(guarded(_location) ? _location : '/dashboard');
    notifyListeners();
  }

  void signOut() {
    _signedIn = false;
    _refreshEnabled = false;
    _overlayLocation = null;
    final cleared = _demoSession.clear();
    _notice = cleared ? null : storageClearFailureNotice;
    onClearSession?.call();
    AppNavigator.currentTab.value = ShellTab.home;
    _sessionEpoch++;
    _setLocation('/login');
    notifyListeners();
  }

  void _setLocation(String path) {
    final storageWarning = _notice == storageUnavailableNotice || _notice == storageClearFailureNotice ? _notice : null;
    if (path == '/assessment') {
      _notice = blankAssessmentNotice;
    } else if (path == '/patient-details') {
      _notice = patientUnavailableNotice;
      path = '/patients';
    } else if (WebRouteParser.temporaryPaths.contains(path)) {
      _notice = _signedIn ? lostStateNotice : lostStateGateNotice;
      path = '/dashboard';
    } else if (path != '/dashboard' && (_notice == lostStateNotice || _notice == lostStateGateNotice)) {
      _notice = null;
    } else if (_notice == blankAssessmentNotice || (path != '/patients' && _notice == patientUnavailableNotice)) {
      _notice = null;
    }
    _location = path;
    // A draft/list reset message must not hide a browser-storage warning.
    if (storageWarning != null) _notice = storageWarning;
    _applyingTab = true;
    AppNavigator.currentTab.value = switch (path) {
      '/patients' => ShellTab.patients,
      '/profile' || '/how-aiovy-works' => ShellTab.profile,
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
    _validateStoredMode();
    // Browser history never reconstructs disposed assessment state. Remounting
    // also removes any old imperative page/dialog instead of leaving it on top.
    _sessionEpoch++;
    _overlayLocation = null;
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
      hasDemoAccess: () => _signedIn,
      child: Column(
        children: [
          if (_signedIn)
            Material(
              color: AppColors.brandTint,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(children: [
                    Expanded(
                        child: Semantics(
                      label: 'DEMO-ONLY browser session. Not authentication. '
                          '${_refreshEnabled ? 'Refresh keeps access, not patient data.' : 'Access lasts only until refresh.'}',
                      excludeSemantics: true,
                      child: Text(
                          MediaQuery.sizeOf(context).width < 400 && MediaQuery.textScalerOf(context).scale(12) > 18
                              ? 'DEMO-ONLY'
                              : 'DEMO-ONLY · not authentication',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurface)),
                    )),
                    if (MediaQuery.sizeOf(context).width < 400 && MediaQuery.textScalerOf(context).scale(12) > 18)
                      Semantics(
                          label: 'Logout',
                          button: true,
                          child: IconButton(
                            onPressed: signOut,
                            icon: const Icon(Icons.logout),
                          ))
                    else
                      TextButton(onPressed: signOut, child: const Text('Logout')),
                  ]),
                ),
              ),
            ),
          if (_notice != null)
            Material(
              color: AppColors.surfaceContainer,
              child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.25),
                  child: SingleChildScrollView(
                      child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                            child: Semantics(
                                liveRegion: true, child: Text(_notice!, style: const TextStyle(fontSize: 12)))),
                        Semantics(
                            label: 'Dismiss notice',
                            button: true,
                            child: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _notice = null;
                                  notifyListeners();
                                })),
                      ]),
                    ),
                  ))),
            ),
          Expanded(
              child: Navigator(
            key: navigatorKey,
            observers: [_observer],
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
                    child: switch (_location) {
                      '/' => const WelcomeScreen(),
                      '/onboarding' => const OnboardingScreen(),
                      _ => const LoginScreen(),
                    })
              else ...[
                MaterialPage<void>(key: ValueKey('shell-$_sessionEpoch'), name: '/dashboard', child: const MainShell()),
                if (_location == '/settings')
                  const MaterialPage<void>(key: ValueKey('settings'), name: '/settings', child: SettingsScreen()),
                if (_location == '/how-aiovy-works')
                  const MaterialPage<void>(
                      key: ValueKey('how-aiovy-works'), name: '/how-aiovy-works', child: ResearchScreen()),
                if (_location == '/assessment')
                  MaterialPage<void>(
                      key: ValueKey('assessment-$_sessionEpoch'),
                      name: '/assessment',
                      child: const AssessmentInputScreen()),
              ],
            ],
            onDidRemovePage: (page) {
              if (page.name != _location) return;
              if (_location == '/settings') {
                go('/dashboard');
              } else if (_location == '/how-aiovy-works') {
                go('/profile');
              } else if (_location == '/assessment') {
                go('/dashboard');
              }
            },
          )),
        ],
      ),
    );
  }

  void _stackChanged(List<Route<dynamic>> routes) {
    final rootKey = _signedIn && guarded(_location)
        ? ValueKey('shell-$_sessionEpoch')
        : ValueKey('gate-$_sessionEpoch-${_location == '/' ? 'intro' : 'login'}');
    if (!routes.any((route) => route.settings is Page && (route.settings as Page).key == rootKey)) {
      return;
    }
    String? temporary;
    for (final route in routes) {
      if (route.settings is Page) {
        temporary = null;
        continue;
      }
      final name = route.settings.name;
      if (WebRouteParser.paths.contains(name) && (_signedIn || WebRouteParser.publicPaths.contains(name))) {
        temporary = name;
      }
    }
    if (temporary == _overlayLocation) return;
    _overlayLocation = temporary;
    if (temporary == '/patient-details' && _notice == patientUnavailableNotice) {
      _notice = null;
    }
    if (temporary != null && temporary != '/assessment' && _notice == blankAssessmentNotice) _notice = null;
    if (temporary == '/how-aiovy-works' && (_notice == lostStateNotice || _notice == lostStateGateNotice)) {
      _notice = null;
    }
    notifyListeners();
  }

  void _validateStoredMode() {
    // A browser can resume a cached document with an older Dart heap. Its
    // previous demo flag must not override a marker removed during logout.
    if (_signedIn && _refreshEnabled && !_demoSession.canRestore) signOut();
  }

  @override
  void dispose() {
    _stopWatching?.call();
    _observer.active = false;
    AppNavigator.currentTab.removeListener(_tabChanged);
    super.dispose();
  }
}

/// Reports only generic page kinds; route arguments and widget data never enter
/// browser history. Notifications wait until Navigator has finished its frame.
class _StackObserver extends NavigatorObserver {
  _StackObserver(this.changed);
  final void Function(List<Route<dynamic>>) changed;
  final _routes = <Route<dynamic>>[];
  bool _scheduled = false;
  bool active = true;
  void _report() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (active && navigator != null && navigator!.mounted) changed(List.of(_routes));
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _report();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _report();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _report();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _report();
  }
}
