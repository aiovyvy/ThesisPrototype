import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/app_settings.dart';
import 'data/repositories/patient_repository.dart';
import 'models/clinician.dart';
import 'navigation/app_navigator.dart';
import 'navigation/web_router.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/risk_classifier.dart';
import 'state/app_scope.dart';

class AiovyApp extends StatefulWidget {
  const AiovyApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.classifier,
    required this.clinician,
  });

  final PatientRepository repository;
  final AppSettings settings;
  final RiskClassifier classifier;
  final Clinician clinician;

  @override
  State<AiovyApp> createState() => _AiovyAppState();
}

class _AiovyAppState extends State<AiovyApp> {
  late final WebRouter? _webRouter = kIsWeb ? WebRouter(onClearSession: widget.repository.clearSession) : null;

  @override
  void dispose() {
    _webRouter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: widget.repository,
      settings: widget.settings,
      classifier: widget.classifier,
      clinician: widget.clinician,
      child: _webRouter != null
          ? MaterialApp.router(
              title: 'AIOVY',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              scaffoldMessengerKey: AppNavigator.messengerKey,
              routerDelegate: _webRouter,
              routeInformationParser: WebRouteParser(),
            )
          : MaterialApp(
              title: 'AIOVY',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              scaffoldMessengerKey: AppNavigator.messengerKey,
              home: const WelcomeScreen(),
            ),
    );
  }
}
