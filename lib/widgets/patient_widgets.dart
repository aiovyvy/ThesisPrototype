import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../data/repositories/app_settings.dart';
import '../models/assessment.dart';
import '../models/maternal_indicators.dart';
import '../models/patient.dart';
import '../models/risk_level.dart';
import 'common.dart';
import 'risk_badge.dart';

/// Rounded-square number tile tinted by the patient's current risk.
class PatientNumberTile extends StatelessWidget {
  const PatientNumberTile({super.key, required this.patient, this.size = 44});

  final Patient patient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final risk = patient.currentRisk;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: risk?.tint ?? AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (risk?.color ?? AppColors.outline).withAlpha(45)),
        ),
        child: Text(
          patient.shortNumber,
          style: AppTextStyles.titleMd.tabular.copyWith(color: risk?.textColor ?? AppColors.onSurface),
        ),
      ),
    );
  }
}

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
            if (i > 0) const Divider(height: 1, indent: 72),
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
    ].join(' · ');

    return Semantics(
      button: true,
      label: 'Patient ${patient.id}, ${patient.age} years, ${level?.label ?? 'not yet assessed'}'
          '${m != null ? ', blood pressure ${m.systolic} over ${m.diastolic}, heart rate ${m.heartRate}' : ''}'
          '${latest != null ? ', assessed ${Fmt.relative(latest.timestamp, withTime: false)}' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, 8, 12),
            child: Row(
              children: [
                PatientNumberTile(patient: patient),
                const SizedBox(width: 12),
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
    return Semantics(
      button: true,
      label: 'Patient ${a.patientId}, ${m.age} years, ${level.label}, '
          'assessed ${Fmt.relative(a.timestamp)}. Blood pressure ${m.systolic} over ${m.diastolic}.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, 8, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Center(
                    child: Icon(level.icon, size: 22, color: level.color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient ${a.patientId}', style: AppTextStyles.labelLg),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.relative(a.timestamp)} · BP ${m.systolic}/${m.diastolic}',
                        style: AppTextStyles.bodySm.tabular.copyWith(color: AppColors.onSurfaceVariant),
                      ),
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
      children: [
        ValueTile(label: 'Blood pressure', value: '${m.systolic}/${m.diastolic}', unit: 'mmHg'),
        ValueTile(label: 'Age', value: '${m.age}', unit: 'yrs'),
        ValueTile(
          label: 'Blood glucose',
          value: Fmt.glucose(m.bloodGlucose, settings.glucoseUnit),
          unit: settings.glucoseUnit.label,
        ),
        ValueTile(
          label: 'Body temperature',
          value: Fmt.temp(m.bodyTempF, settings.tempUnit),
          unit: settings.tempUnit.label,
        ),
        ValueTile(label: 'Heart rate', value: '${m.heartRate}', unit: 'bpm'),
      ],
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
