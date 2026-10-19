import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/app_settings.dart';
import '../../models/assessment.dart';
import '../../models/patient.dart';
import '../../models/risk_level.dart';
import '../../navigation/app_navigator.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/patient_widgets.dart';
import '../assessment/assessment_input_screen.dart';
import '../result/result_screen.dart';

/// Stitch: patient_profile_history. A focused detail screen: current status,
/// one primary action, the latest values, then history.
class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  RiskLevel? _historyFilter;

  Future<void> _pickFilter() async {
    final picked = await showModalBottomSheet<_FilterChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceLowest,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Filter assessment history', style: AppTextStyles.titleMd),
              ),
            ),
            _sheetOption(ctx, 'All results', null, Icons.list_alt),
            for (final l in RiskLevel.values) _sheetOption(ctx, l.label, l, l.icon, color: l.color),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _historyFilter = picked.level);
  }

  Widget _sheetOption(BuildContext ctx, String label, RiskLevel? level, IconData icon, {Color? color}) {
    final selected = _historyFilter == level;
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.onSurfaceVariant),
      title: Text(label, style: AppTextStyles.bodyLg),
      trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () => Navigator.pop(ctx, _FilterChoice(level)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Patient ${widget.patientId}',
        style: HeaderStyle.backCentered,
        actions: [
          RoundIconButton(
            icon: Icons.ios_share,
            tooltip: 'Export or print record',
            background: Colors.transparent,
            foreground: AppColors.primary,
            onPressed: () => AppNavigator.showSnack(
              'Export and printing are not available in the prototype.',
              icon: Icons.info_outline,
            ),
          ),
        ],
      ),
      body: AppStateBuilder(builder: (context, scope) {
        final p = scope.repository.byId(widget.patientId);
        if (p == null) {
          return const Center(child: Text('Patient not found'));
        }
        final s = scope.settings;
        final latest = p.latest;
        final history =
            p.assessments.where((a) => _historyFilter == null || a.result.riskLevel == _historyFilter).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.margin, AppSpacing.md, AppSpacing.margin, AppSpacing.xl),
          children: [
            _StatusCard(patient: p),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'New assessment',
              leadingIcon: Icons.add_circle_outline,
              onPressed: () => AppNavigator.push(context, AssessmentInputScreen(patientId: p.id)),
            ),
            if (latest != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SectionTitle('Latest values', caption: Fmt.relative(latest.timestamp)),
              const SizedBox(height: AppSpacing.sm),
              IndicatorGrid(indicators: latest.indicators, settings: s),
            ],
            const SizedBox(height: AppSpacing.lg),
            SectionTitle(
              'Assessment history (${p.assessments.length})',
              trailing: LinkButton(
                label: _historyFilter == null ? 'Filter' : _historyFilter!.shortLabel,
                leadingIcon: Icons.tune,
                onPressed: _pickFilter,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (history.isEmpty)
              const InfoNote(text: 'No assessments match this filter.', icon: Icons.filter_list)
            else
              _Timeline(assessments: history, all: p.assessments, settings: s),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Demo records only · no real patient data',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
            ),
          ],
        );
      }),
    );
  }
}

class _FilterChoice {
  const _FilterChoice(this.level);
  final RiskLevel? level;
}

/// Current risk status first, then who the patient is.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final latest = patient.latest;
    final level = latest?.result.riskLevel;
    final hasContext = patient.gestationalAge != null || patient.clinicalNote != null;
    return Container(
      decoration: BoxDecoration(
        color: level?.tint ?? AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: level == null ? AppColors.border : level.color.withAlpha(70)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: level?.icon ?? Icons.person_outline,
                size: 52,
                iconSize: 28,
                radius: 14,
                background: AppColors.surfaceLowest,
                foreground: level?.color ?? AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT STATUS', style: AppTextStyles.overline),
                    const SizedBox(height: 2),
                    Semantics(
                      header: true,
                      child: Text(
                        level?.label ?? 'Not yet assessed',
                        style: AppTextStyles.headlineMd.copyWith(color: level?.textColor ?? AppColors.onSurface),
                      ),
                    ),
                    if (latest != null)
                      Text(
                        'Latest assessment · ${Fmt.relative(latest.timestamp)}',
                        style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            [
              '${patient.age} years',
              if (patient.gestationalAge != null) 'Gestational age ${patient.gestationalAge}',
            ].join(' · '),
            style: AppTextStyles.labelLg,
          ),
          if (patient.clinicalNote != null) ...[
            const SizedBox(height: 4),
            Text(patient.clinicalNote!, style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
          ],
          if (hasContext) ...[
            const SizedBox(height: 6),
            // Clearly separated from the six model indicators.
            Text(
              'Pregnancy context · not a model input',
              style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.assessments, required this.all, required this.settings});

  /// The (possibly filtered) assessments to show, newest first.
  final List<Assessment> assessments;

  /// Every assessment for the patient, newest first – used to find each
  /// one's previous result even when a filter hides it.
  final List<Assessment> all;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return GroupedList(
      children: [
        for (final a in assessments)
          _HistoryRow(
            assessment: a,
            previous: () {
              final i = all.indexOf(a);
              return i >= 0 && i + 1 < all.length ? all[i + 1] : null;
            }(),
            settings: settings,
          ),
      ],
    );
  }
}

/// The whole row opens the (read-only) result for that assessment.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.assessment, required this.previous, required this.settings});

  final Assessment assessment;
  final Assessment? previous;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final m = a.indicators;
    final level = a.result.riskLevel;
    final vitals = [
      'BP ${m.systolic}/${m.diastolic}',
      'HR ${m.heartRate}',
      'BG ${Fmt.glucose(m.bloodGlucose, settings.glucoseUnit)} ${settings.glucoseUnit.label}',
    ].map(keepTogether).join(' · ');
    final prev = previous?.result.riskLevel;
    return Semantics(
      button: true,
      label: '${Fmt.relative(a.timestamp)}, ${level.label}'
          '${prev == null ? '' : (prev == level ? ', same as previous' : ', previously ${prev.label}')}. '
          '$vitals. ${a.type} by ${a.assessedBy}. Open result and explanation.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => AppNavigator.push(context, ResultScreen(assessment: a)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(level.icon, size: 22, color: level.color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(level.label, style: AppTextStyles.labelLg.copyWith(color: level.textColor)),
                        if (prev != null) RiskChangeMarker(current: level, previous: prev),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.relative(a.timestamp),
                      style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 6),
                    Text(vitals, style: AppTextStyles.bodySm.tabular.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      '${a.type} · ${a.assessedBy}',
                      style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.outline),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right, color: AppColors.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
