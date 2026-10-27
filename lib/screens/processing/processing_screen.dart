import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/assessment.dart';
import '../../models/maternal_indicators.dart';
import '../../navigation/route_session.dart';
import '../../models/risk_result.dart';
import '../../navigation/app_navigator.dart';
import '../../services/risk_classifier.dart';
import '../../state/app_scope.dart';
import '../../widgets/aiovy_logo.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/research_disclaimer.dart';
import '../result/result_screen.dart';

/// Runs the classifier, then replaces itself with the result.
///
/// Awaits one combined prediction and explanation response, without artificial
/// delays or simulated backend stages. If classification fails,
/// the screen shows the reason with **Try again** and **Edit values**; the
/// entered values are kept on the form underneath.
class ProcessingScreen extends StatefulWidget implements TemporaryWebPage {
  const ProcessingScreen({super.key, required this.patientId, required this.indicators, required this.isNewPatient});

  final String patientId;
  final MaternalIndicators indicators;
  final bool isNewPatient;

  @override
  String get temporaryWebLocation => '/processing';

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  bool _inFlight = false;
  bool _started = false;

  /// Shown instead of the progress view when classification failed.
  String? _error;

  /// Incremented per run so a late completion from an earlier run is ignored.
  int _attempt = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  Future<void> _run() async {
    if (_inFlight || !mounted) return;
    _inFlight = true;
    final attempt = ++_attempt;
    final scope = AppScope.of(context);
    // The first call starts during didChangeDependencies. Retry clears the
    // error immediately; the synchronous guard also blocks repeated taps.
    if (_error != null) setState(() => _error = null);

    final RiskResult result;
    try {
      result = await scope.classifier.classify(widget.indicators);
    } on RiskClassifierException catch (e) {
      _fail(e.message, attempt);
      return;
    } catch (_) {
      _fail('Something went wrong while classifying. Try again, or check the indicator values.', attempt);
      return;
    }
    if (!mounted || !_mayComplete(attempt)) return;

    final now = DateTime.now();
    final assessment = Assessment(
      id: 'A-${widget.patientId}-${now.millisecondsSinceEpoch}',
      patientId: widget.patientId,
      timestamp: now,
      indicators: widget.indicators,
      result: result,
      assessedBy: scope.clinician.displayName,
      type: widget.isNewPatient ? 'Initial Intake' : 'Routine Assessment',
    );

    AppNavigator.replace(context, ResultScreen(assessment: assessment), rise: true);
  }

  // A popped route can remain mounted during its reverse transition. Also
  // check route ownership and session access before accepting a late response.
  bool _mayComplete(int attempt) =>
      mounted &&
      attempt == _attempt &&
      ModalRoute.of(context)?.isCurrent == true &&
      RouteSession.maybeOf(context)?.hasDemoAccess?.call() != false;

  void _fail(String message, int attempt) {
    if (!_mayComplete(attempt)) return;
    setState(() {
      _inFlight = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final error = _error;
    return Scaffold(
      appBar: AppHeader(title: error == null ? 'Assessing' : 'Assessment not completed', showLogo: false),
      bottomNavigationBar: error == null
          ? null
          : StickyActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(label: 'Try again', leadingIcon: Icons.refresh, onPressed: _run),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Edit values',
                    leadingIcon: Icons.edit_outlined,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
      body: error == null ? _progress(scope) : _failure(error),
    );
  }

  Widget _progress(AppScope scope) {
    return ListView(
      padding: AppLayout.page(context, top: AppSpacing.xl, bottom: AppSpacing.lg),
      children: [
        const ResearchDisclaimer(),
        const SizedBox(height: AppSpacing.md),
        const Center(child: _Spinner()),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Text(
            'Assessing Patient ${widget.patientId}',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSm,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Waiting for the model prediction, class probabilities, and feature explanation.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          scope.classifier.isDemo
              ? 'Demo classifier · not a trained model · ${AppStrings.versionShort}'
              : 'Model: ${scope.classifier.modelName}',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.outline),
        ),
      ],
    );
  }

  Widget _failure(String message) {
    return ListView(
      padding: AppLayout.page(context, top: AppSpacing.xl, bottom: AppSpacing.lg),
      children: [
        const ResearchDisclaimer(),
        const SizedBox(height: AppSpacing.md),
        const Center(
          child: IconTile(
            icon: Icons.cloud_off_outlined,
            size: 64,
            iconSize: 30,
            circle: true,
            background: AppColors.errorTint,
            foreground: AppColors.error,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text("Couldn't get a risk result", textAlign: TextAlign.center, style: AppTextStyles.headlineSm),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        InfoNote(
          icon: Icons.inventory_2_outlined,
          text: 'Nothing was saved. The values you entered for Patient ${widget.patientId} are kept, '
              'so you can try again or correct them.',
        ),
      ],
    );
  }
}

/// Brand mark inside a slow progress ring. Static when the system asks for
/// reduced motion.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 112,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 112,
              child: CircularProgressIndicator(
                value: reduceMotion ? 1 : null,
                strokeWidth: 3,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceContainer,
              ),
            ),
            const AiovyLogoMark(size: 72),
          ],
        ),
      ),
    );
  }
}
