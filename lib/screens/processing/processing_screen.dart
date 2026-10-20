import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/app_settings.dart';
import '../../models/assessment.dart';
import '../../models/maternal_indicators.dart';
import '../../models/risk_result.dart';
import '../../navigation/app_navigator.dart';
import '../../services/risk_classifier.dart';
import '../../state/app_scope.dart';
import '../../widgets/aiovy_logo.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../result/result_screen.dart';

/// Runs the classifier, then replaces itself with the result.
///
/// The step list is paced for readability while the classifier call runs in
/// parallel. If the classifier fails (e.g. the API server is unreachable),
/// the screen shows the reason with **Try again** and **Edit values**; the
/// entered values are kept on the form underneath.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.patientId, required this.indicators, required this.isNewPatient});

  final String patientId;
  final MaternalIndicators indicators;
  final bool isNewPatient;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  /// 0 = validating, 1 = classifying, 2 = SHAP, 3 = done
  int _step = 0;
  final List<Timer> _timers = [];
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
    final attempt = ++_attempt;
    final scope = AppScope.of(context);
    _cancelTimers();
    // The first run starts from the initial state (and must not call setState
    // from didChangeDependencies); a retry resets the view.
    if (attempt > 1) {
      setState(() {
        _error = null;
        _step = 0;
      });
    }
    _timers.add(Timer(const Duration(milliseconds: 700), () => _setStep(1, attempt)));
    _timers.add(Timer(const Duration(milliseconds: 1700), () => _setStep(2, attempt)));

    final RiskResult result;
    try {
      final resultFuture = scope.classifier.classify(widget.indicators);
      await Future.wait([resultFuture, Future<void>.delayed(const Duration(milliseconds: 2600))]);
      result = await resultFuture;
    } on RiskClassifierException catch (e) {
      _fail(e.message, attempt);
      return;
    } catch (_) {
      _fail('Something went wrong while classifying. Try again, or check the indicator values.', attempt);
      return;
    }
    if (!mounted || attempt != _attempt) return;
    _setStep(3, attempt);

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

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || attempt != _attempt) return;
    AppNavigator.replace(context, ResultScreen(assessment: assessment), rise: true);
  }

  void _fail(String message, int attempt) {
    if (!mounted || attempt != _attempt) return;
    _cancelTimers();
    setState(() => _error = message);
  }

  void _setStep(int s, int attempt) {
    if (mounted && attempt == _attempt) setState(() => _step = s);
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
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
    final m = widget.indicators;
    final s = scope.settings;
    final temp = '${Fmt.temp(m.bodyTempF, s.tempUnit)}${s.tempUnit.label}';
    final done = _step >= 3;

    return ListView(
      padding: AppLayout.page(context, top: AppSpacing.xl, bottom: AppSpacing.lg),
      children: [
        Center(child: _Spinner(done: done)),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Text(
            done ? 'Classification complete' : 'Assessing Patient ${widget.patientId}',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSm,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Applying the risk model to six maternal indicators.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            children: [
              _StepRow(
                number: 1,
                title: 'Values checked',
                subtitle: 'BP ${m.systolic}/${m.diastolic} · HR ${m.heartRate} · $temp · '
                    'BG ${Fmt.glucose(m.bloodGlucose, s.glucoseUnit)} ${s.glucoseUnit.label}',
                state: _stateFor(0),
              ),
              const Divider(height: 24),
              _StepRow(
                number: 2,
                title: 'Classifying risk level',
                subtitle: 'Low · Moderate · High probabilities',
                state: _stateFor(1),
              ),
              const Divider(height: 24),
              _StepRow(
                number: 3,
                title: 'Explaining the result',
                subtitle: 'SHAP contribution of each indicator',
                state: _stateFor(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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

  _StepState _stateFor(int index) {
    if (_step > index) return _StepState.done;
    if (_step == index) return _StepState.active;
    return _StepState.pending;
  }
}

enum _StepState { pending, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.title, required this.subtitle, required this.state});

  final int number;
  final String title;
  final String subtitle;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final Widget leading = switch (state) {
      _StepState.done => const IconTile(
          icon: Icons.check,
          size: 28,
          iconSize: 17,
          circle: true,
          background: AppColors.riskLowTint,
          foreground: AppColors.riskLow,
        ),
      _StepState.active => const SizedBox(
          width: 28,
          height: 28,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      _StepState.pending => Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outlineVariant, width: 1.5),
          ),
          child: Text('$number', style: AppTextStyles.labelSm.copyWith(color: AppColors.outline)),
        ),
    };
    final stateText = switch (state) {
      _StepState.done => 'complete',
      _StepState.active => 'in progress',
      _StepState.pending => 'waiting',
    };
    return Semantics(
      label: 'Step $number, $title, $stateText',
      excludeSemantics: true,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLg.copyWith(
                    color: state == _StepState.pending ? AppColors.onSurfaceVariant : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand mark inside a slow progress ring. Static when the system asks for
/// reduced motion.
class _Spinner extends StatelessWidget {
  const _Spinner({required this.done});

  final bool done;

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
                value: done || reduceMotion ? 1 : null,
                strokeWidth: 3,
                color: done ? AppColors.riskLow : AppColors.primary,
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
