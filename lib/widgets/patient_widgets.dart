import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../data/repositories/app_settings.dart';
import '../models/assessment.dart';
import '../models/maternal_indicators.dart';
import '../models/patient.dart';
import '../models/risk_level.dart';
import '../models/risk_result.dart';
import '../state/app_scope.dart';
import 'common.dart';
import 'risk_badge.dart';

/// Makes one value (e.g. "HR 82", "5.6 mmol/L") unbreakable: spaces become
/// non-breaking and a word joiner follows each "/". Join such values with
/// " · " so lines wrap only between values, never inside one.
String keepTogether(String s) =>
    s.replaceAll(' ', String.fromCharCode(0xA0)).replaceAll('/', '/${String.fromCharCode(0x2060)}');

/// A white group of rows separated by hairlines (lists on Home / Patients).
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpacing.md),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One patient as a dense, tappable row: number tile · ID and latest vitals
/// · risk badge. Used on Patients and in Home's "Needs review".
class PatientListRow extends StatelessWidget {
  const PatientListRow({super.key, required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = patient.latest;
    final level = patient.currentRisk;
    final m = latest?.indicators;
    final meta = [
      '${patient.age} yrs',
      if (m != null) 'BP ${m.systolic}/${m.diastolic}',
      if (m != null) 'HR ${m.heartRate}',
    ].map(keepTogether).join(' · ');
    final simulated = latest != null && needsSimulatedTag(context, latest.result);

    return Semantics(
      button: true,
      label: 'Patient ${patient.id}, ${patient.age} years, ${level?.label ?? 'not yet assessed'}'
          '${simulated ? ' (simulated)' : ''}'
          '${m != null ? ', blood pressure ${m.systolic} over ${m.diastolic}, heart rate ${m.heartRate}' : ''}'
          '${latest != null ? ', assessed ${Fmt.relative(latest.timestamp, withTime: false)}' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // The full ID is never truncated.
                          Text(patient.id, style: AppTextStyles.labelLg),
                          if (latest != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                Fmt.relative(latest.timestamp, withTime: false),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(
                                      color: AppColors.outline,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: AppTextStyles.bodySm.tabular.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      if (simulated) ...[const SizedBox(height: 2), const SimulatedTag()],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (level != null) RiskBadge(level: level, short: true),
                const Icon(Icons.chevron_right, size: 22, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One assessment as a dense row (Home → Recent assessments).
class AssessmentListRow extends StatelessWidget {
  const AssessmentListRow({super.key, required this.assessment, required this.onTap});

  final Assessment assessment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final level = a.result.riskLevel;
    final m = a.indicators;
    final simulated = needsSimulatedTag(context, a.result);
    return Semantics(
      button: true,
      label: 'Patient ${a.patientId}, ${m.age} years, ${level.label}${simulated ? ' (simulated)' : ''}, '
          'assessed ${Fmt.relative(a.timestamp)}. Blood pressure ${m.systolic} over ${m.diastolic}.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient ${a.patientId}', style: AppTextStyles.labelLg),
                      const SizedBox(height: 2),
                      Text(
                        [Fmt.relative(a.timestamp), 'BP ${m.systolic}/${m.diastolic}'].map(keepTogether).join(' · '),
                        style: AppTextStyles.bodySm.tabular.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      if (simulated) ...[const SizedBox(height: 2), const SimulatedTag()],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RiskBadge(level: level, short: true),
                const Icon(Icons.chevron_right, size: 22, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The six inputs as a compact two-column grid of tiles (blood pressure
/// shown as one "142/92" tile) in the clinician's units. Used on the Result
/// and Patient Profile screens.
class IndicatorGrid extends StatelessWidget {
  const IndicatorGrid({super.key, required this.indicators, required this.settings});

  final MaternalIndicators indicators;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final m = indicators;
    return ResponsiveGrid(
      minItemWidth: 128,
      spacing: 14,
      children: [
        _Reading('Blood pressure', '${m.systolic}/${m.diastolic}', 'mmHg'),
        _Reading('Age', '${m.age}', 'yrs'),
        _Reading('Blood glucose', Fmt.glucose(m.bloodGlucose, settings.glucoseUnit), settings.glucoseUnit.label),
        _Reading('Body temperature', Fmt.temp(m.bodyTempF, settings.tempUnit), settings.tempUnit.label),
        _Reading('Heart rate', '${m.heartRate}', 'bpm'),
      ],
    );
  }
}

/// One measurement: small label over value + unit, without a box.
class _Reading extends StatelessWidget {
  const _Reading(this.label, this.value, this.unit);

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value $unit',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 1),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: AppTextStyles.titleMd.tabular),
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "↑ from Moderate" marker: how this assessment's level compares with
/// the patient's previous one. Purely a comparison of saved results.
class RiskChangeMarker extends StatelessWidget {
  const RiskChangeMarker({super.key, required this.current, required this.previous});

  final RiskLevel current;
  final RiskLevel previous;

  @override
  Widget build(BuildContext context) {
    final diff = current.index - previous.index;
    final (icon, text) = diff > 0
        ? (Icons.arrow_upward, 'Up from ${previous.shortLabel}')
        : diff < 0
            ? (Icons.arrow_downward, 'Down from ${previous.shortLabel}')
            : (Icons.remove, 'No change');
    return Semantics(
      label: diff == 0 ? 'Same level as previous assessment' : '$text at previous assessment',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(text, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// True when [result] is simulated but appears alongside trained-model
/// results (API mode), so it needs its own marker. In demo mode everything
/// is simulated and [PredictionModeNote] says so once instead.
bool needsSimulatedTag(BuildContext context, RiskResult result) =>
    result.isDemo && !AppScope.of(context).classifier.isDemo;

/// Small "Simulated" marker for one result in a list.
class SimulatedTag extends StatelessWidget {
  const SimulatedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.science_outlined, size: 13, color: AppColors.outline),
        const SizedBox(width: 3),
        Text(
          AppStrings.simulatedShort,
          style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.outline),
        ),
      ],
    );
  }
}

/// One line, shown only in demo mode, saying every prediction is simulated.
class PredictionModeNote extends StatelessWidget {
  const PredictionModeNote({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppScope.of(context).classifier.isDemo) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.science_outlined, size: 18, color: AppColors.riskModerateText),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo mode: every prediction is simulated by a built-in classifier, not the trained model.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
