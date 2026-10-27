import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/app_settings.dart';
import '../../models/maternal_indicators.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/route_session.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/research_disclaimer.dart';
import '../processing/processing_screen.dart';
import 'indicator_input_card.dart';
import 'indicator_spec.dart';

/// Stitch: patient_assessment_input. Collects the six model indicators.
class AssessmentInputScreen extends StatefulWidget implements RestorableWebPage {
  const AssessmentInputScreen({super.key, this.patientId});

  /// Existing patient, or null to auto-assign a new demo ID.
  final String? patientId;

  @override
  String get restorableWebLocation => '/assessment';
  @override
  bool get requiresDemoAccess => true;

  @override
  State<AssessmentInputScreen> createState() => _AssessmentInputScreenState();
}

class _AssessmentInputScreenState extends State<AssessmentInputScreen> {
  /// Stitch demo values, entered only when the clinician taps
  /// "Fill demo values" – never pre-filled silently.
  static const _demoValues =
      MaternalIndicators(age: 29, systolic: 120, diastolic: 84, bloodGlucose: 5.6, bodyTempF: 98.4, heartRate: 78);

  final Map<Indicator, TextEditingController> _ctrl = {
    for (final i in Indicator.values) i: TextEditingController(),
  };
  final Map<Indicator, FocusNode> _focus = {for (final i in Indicator.values) i: FocusNode()};

  /// Field text when the screen opened; used to detect unsaved edits.
  final Map<Indicator, String> _initial = {};

  late String _patientId;
  late bool _isNewPatient;
  DateTime? _prefilledFrom;
  bool _submitted = false;
  bool _submitting = false;
  bool _initialised = false;
  GlucoseUnit? _glucoseUnit;
  TempUnit? _tempUnit;
  AppSettings? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;

    final scope = AppScope.of(context);
    _settings = scope.settings..addListener(_onSettingsChanged);
    _glucoseUnit = scope.settings.glucoseUnit;
    _tempUnit = scope.settings.tempUnit;
    final existing = widget.patientId == null ? null : scope.repository.byId(widget.patientId!);
    _isNewPatient = existing == null;
    _patientId = existing?.id ?? scope.repository.nextPatientId();

    // Existing patients start from their last recorded values (labelled as
    // such on screen). New patients always start empty.
    final latest = existing?.latest;
    if (latest != null) {
      _fill(latest.indicators);
      _prefilledFrom = latest.timestamp;
    }
    for (final i in Indicator.values) {
      _initial[i] = _ctrl[i]!.text;
    }
  }

  void _fill(MaternalIndicators m) {
    final s = AppScope.of(context).settings;
    _ctrl[Indicator.age]!.text = '${m.age}';
    _ctrl[Indicator.systolic]!.text = '${m.systolic}';
    _ctrl[Indicator.diastolic]!.text = '${m.diastolic}';
    _ctrl[Indicator.bloodGlucose]!.text = Fmt.glucose(m.bloodGlucose, s.glucoseUnit);
    _ctrl[Indicator.bodyTemperature]!.text = Fmt.temp(m.bodyTempF, s.tempUnit);
    _ctrl[Indicator.heartRate]!.text = '${m.heartRate}';
  }

  /// "today", "yesterday" or "Oct 2, 2026", for use mid-sentence.
  static String _when(DateTime t) {
    final s = Fmt.relative(t, withTime: false);
    return s == 'Today' || s == 'Yesterday' ? s.toLowerCase() : s;
  }

  bool get _hasEdits => Indicator.values.any((i) => _ctrl[i]!.text != (_initial[i] ?? ''));

  bool get _hasAnyValue => _ctrl.values.any((c) => c.text.trim().isNotEmpty);

  void _onSettingsChanged() {
    final s = _settings;
    if (s != null && mounted) _syncUnits(s);
  }

  @override
  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    for (final c in _ctrl.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  FieldStatus _status(Indicator i, AppSettings s) {
    final base = IndicatorSpec.of(i, s).check(_ctrl[i]!.text);
    if (base != FieldStatus.valid) return base;
    if (i == Indicator.diastolic) {
      final sys = double.tryParse(_ctrl[Indicator.systolic]!.text.trim());
      final dia = double.tryParse(_ctrl[Indicator.diastolic]!.text.trim());
      if (sys != null && dia != null && dia >= sys) return FieldStatus.crossCheck;
    }
    return FieldStatus.valid;
  }

  void _clearAll() {
    for (final c in _ctrl.values) {
      c.clear();
    }
    setState(() => _submitted = false);
    _focus[Indicator.age]!.requestFocus();
  }

  void _fillDemo() {
    FocusScope.of(context).unfocus();
    setState(() => _fill(_demoValues));
  }

  Future<void> _confirmLeave() async {
    final discard = await confirmDiscard(
      context,
      title: 'Discard entered values?',
      message: 'The indicator values you entered for Patient $_patientId have not been assessed and will be lost.',
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  Future<void> _submit(AppSettings s) async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final invalid = Indicator.values.where((i) => _status(i, s) != FieldStatus.valid).toList();
    if (invalid.isNotEmpty) {
      // Feedback stays in the sticky bar and on the fields themselves (a
      // floating snackbar would cover the "Assess Risk" button).
      HapticFeedback.lightImpact();
      setState(() => _submitted = true);
      _focus[invalid.first]!.requestFocus();
      return;
    }

    double v(Indicator i) => double.parse(_ctrl[i]!.text.trim());
    final indicators = MaternalIndicators(
      age: v(Indicator.age).round(),
      systolic: v(Indicator.systolic).round(),
      diastolic: v(Indicator.diastolic).round(),
      bloodGlucose: Fmt.fromDisplayGlucose(v(Indicator.bloodGlucose), s.glucoseUnit),
      bodyTempF: Fmt.fromDisplayTemp(v(Indicator.bodyTemperature), s.tempUnit),
      heartRate: v(Indicator.heartRate).round(),
    );

    _submitting = true;
    try {
      await AppNavigator.pushFade(
        context,
        ProcessingScreen(patientId: _patientId, indicators: indicators, isNewPatient: _isNewPatient),
      );
    } finally {
      _submitting = false;
    }
  }

  /// Converts already-typed values if the unit setting changed meanwhile.
  void _syncUnits(AppSettings s) {
    void convert(Indicator i, String Function(double) to) {
      final c = _ctrl[i]!;
      final v = double.tryParse(c.text.trim());
      if (v == null) return;
      final untouched = c.text == _initial[i];
      c.text = to(v);
      if (untouched) _initial[i] = c.text; // a unit switch is not an edit
    }

    if (_glucoseUnit != null && _glucoseUnit != s.glucoseUnit) {
      final from = _glucoseUnit!;
      convert(Indicator.bloodGlucose, (v) => Fmt.glucose(Fmt.fromDisplayGlucose(v, from), s.glucoseUnit));
    }
    if (_tempUnit != null && _tempUnit != s.tempUnit) {
      final from = _tempUnit!;
      convert(Indicator.bodyTemperature, (v) => Fmt.temp(Fmt.fromDisplayTemp(v, from), s.tempUnit));
    }
    _glucoseUnit = s.glucoseUnit;
    _tempUnit = s.tempUnit;
  }

  IndicatorFieldData _field(Indicator i, AppSettings s, Map<Indicator, FieldStatus> statuses) {
    final n = Indicator.values.indexOf(i);
    final isLast = n == Indicator.values.length - 1;
    return IndicatorFieldData(
      spec: IndicatorSpec.of(i, s),
      controller: _ctrl[i]!,
      focusNode: _focus[i]!,
      status: statuses[i]!,
      showErrors: _submitted || _ctrl[i]!.text.isNotEmpty,
      crossCheckMessage: 'Must be lower than systolic',
      isLast: isLast,
      onChanged: (_) => setState(() {}),
      onSubmitted: () {
        if (!isLast) {
          _focus[Indicator.values[n + 1]]!.requestFocus();
        } else {
          FocusScope.of(context).unfocus();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read here, above the Scaffold: Scaffold removes the keyboard inset from
    // the MediaQuery its body sees.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: !_hasEdits,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppHeader(title: _isNewPatient ? 'New assessment' : 'Assessment', showLogo: false),
        body: AppStateBuilder(
          builder: (context, scope) {
            final s = scope.settings;
            final statuses = {for (final i in Indicator.values) i: _status(i, s)};
            IndicatorFieldData f(Indicator i) => _field(i, s, statuses);

            final Widget? formAction = _hasAnyValue
                ? LinkButton(label: 'Clear all', color: AppColors.onSurfaceVariant, onPressed: _clearAll)
                : _isNewPatient
                    ? LinkButton(label: 'Use sample values', color: AppColors.onSurfaceVariant, onPressed: _fillDemo)
                    : null;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: AppLayout.page(context, top: AppSpacing.md, bottom: AppSpacing.lg),
                    children: [
                      const ResearchDisclaimer(),
                      const SizedBox(height: AppSpacing.md),
                      _PatientStrip(patientId: _patientId, isNew: _isNewPatient, action: formAction),
                      const SizedBox(height: 10),
                      // The one place real patient data could be typed in.
                      const _SyntheticOnlyNote(),
                      if (_prefilledFrom != null) ...[
                        const SizedBox(height: 12),
                        InfoNote(
                          icon: Icons.history,
                          title: 'Copied from the last visit',
                          text: 'These values are from ${_when(_prefilledFrom!)}. '
                              'Measure again and update each one before assessing.',
                          background: AppColors.riskModerateTint,
                          iconColor: AppColors.riskModerateText,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _Group(title: 'Mother', children: [IndicatorFieldRow(data: f(Indicator.age))]),
                      const SizedBox(height: 12),
                      _Group(
                        title: 'Blood pressure',
                        children: [
                          BloodPressureFields(systolic: f(Indicator.systolic), diastolic: f(Indicator.diastolic)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Group(
                        title: 'Other vital signs',
                        children: [
                          IndicatorFieldRow(data: f(Indicator.bloodGlucose)),
                          IndicatorFieldRow(data: f(Indicator.bodyTemperature)),
                          IndicatorFieldRow(data: f(Indicator.heartRate)),
                        ],
                      ),
                    ],
                  ),
                ),
                _AssessBar(
                  keyboardOpen: keyboardOpen,
                  statuses: [for (final i in Indicator.values) statuses[i]!],
                  showErrors: _submitted,
                  onAssess: () => _submit(s),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A titled white group of related inputs, separated by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title.toUpperCase(), style: AppTextStyles.overline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 28),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Who is being assessed, with the form-level action (sample / clear).
class _PatientStrip extends StatelessWidget {
  const _PatientStrip({required this.patientId, required this.isNew, this.action});

  final String patientId;
  final bool isNew;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Patient $patientId', style: AppTextStyles.headlineSm),
              ),
              Text(
                isNew ? 'New record' : 'Existing record',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// Sticky bottom bar: a six-segment progress meter + "Assess risk".
///
/// The button is never disabled: tapping it with missing values highlights
/// them and moves focus to the first one, which is easier to understand than
/// a greyed-out button.
class _AssessBar extends StatelessWidget {
  const _AssessBar({
    required this.statuses,
    required this.showErrors,
    required this.onAssess,
    required this.keyboardOpen,
  });

  final List<FieldStatus> statuses;

  /// True after a submit attempt: incomplete state is shown as an error.
  final bool showErrors;
  final VoidCallback onAssess;

  /// While the keyboard is up, space is scarce: show only the button.
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) {
    final total = statuses.length;
    final validCount = statuses.where((s) => s == FieldStatus.valid).length;
    final ready = validCount == total;
    final error = showErrors && !ready;
    final statusText = ready
        ? 'Ready to assess'
        : error
            ? 'Check the highlighted values'
            : '$validCount of $total values entered';

    return StickyActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!keyboardOpen) ...[
            Semantics(
              liveRegion: true,
              label: ready
                  ? 'All $total values valid. Ready to assess.'
                  : '$validCount of $total values valid.${error ? ' Check the highlighted values.' : ''}',
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 0; i < total; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: statuses[i] == FieldStatus.valid
                              ? AppColors.sage
                              : (showErrors ? AppColors.error.withAlpha(110) : AppColors.surfaceHigh),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Text(
                    statusText,
                    style: AppTextStyles.labelSm.copyWith(
                      color: ready ? AppColors.sageText : (error ? AppColors.error : AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          PrimaryButton(label: 'Assess risk', trailingIcon: Icons.arrow_forward, onPressed: onAssess),
        ],
      ),
    );
  }
}

/// Reminds the user, where values are entered, that only synthetic data may
/// be used. (The form has no name or free-text fields and IDs are generated,
/// so identifying details cannot be typed in; this covers the vital signs.)
class _SyntheticOnlyNote extends StatelessWidget {
  const _SyntheticOnlyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.shield_outlined, size: 18, color: AppColors.riskModerateText),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppStrings.syntheticDataOnly,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
