import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/research_demo_client.dart';
import '../../widgets/app_header.dart';
import '../../widgets/research_disclaimer.dart';

/// Public fixed examples only. No repository, assessment or session dependency.
class ResearchDemoScreen extends StatefulWidget {
  const ResearchDemoScreen({super.key, this.client, this.exampleId = 'R1', this.onExampleSelected, this.onBack});
  final ResearchDemoClient? client;
  final String exampleId;
  final ValueChanged<String>? onExampleSelected;
  final VoidCallback? onBack;

  @override
  State<ResearchDemoScreen> createState() => _ResearchDemoScreenState();
}

class _ResearchDemoScreenState extends State<ResearchDemoScreen> {
  late final ResearchDemoClient _client;
  late Future<ResearchExample> _result;
  late String _selected;

  static String _fixedId(String id) => ResearchDemoClient.exampleIds.contains(id) ? id : 'R1';

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ResearchDemoClient();
    _selected = _fixedId(widget.exampleId);
    _result = _client.load(_selected);
  }

  @override
  void didUpdateWidget(ResearchDemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exampleId != widget.exampleId) {
      _selected = _fixedId(widget.exampleId);
      _result = _client.load(_selected);
    }
  }

  void _select(String id) {
    if (id == _selected) return;
    if (widget.onExampleSelected != null) {
      widget.onExampleSelected!(id);
    } else {
      final next = _client.load(id);
      setState(() {
        _selected = id;
        _result = next;
      });
    }
  }

  void _retry() {
    final next = _client.load(_selected);
    setState(() {
      _result = next;
    });
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppHeader(title: 'Research Demonstration', style: HeaderStyle.backCentered, onBack: widget.onBack),
        body: LayoutBuilder(builder: (context, bounds) {
          final side = math.max(bounds.maxWidth > 700 ? 28.0 : 16.0, (bounds.maxWidth - 1200) / 2);
          final wide = bounds.maxWidth - side * 2 >= 880 && MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          return Column(children: [
            _warnings(side, wide),
            Expanded(
                child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(side, 24, side, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const ResearchDisclaimer(),
                const SizedBox(height: 16),
                Text('Explore the model, one example at a time', style: AppTextStyles.headlineMd),
                const SizedBox(height: 8),
                const Text('Six fixed held-out records show both correct and incorrect predictions. '
                    'Read only: no measurements can be entered or saved.'),
                const SizedBox(height: 20),
                _selector(),
                const SizedBox(height: 24),
                FutureBuilder<ResearchExample>(
                    future: _result,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                            padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.id != _selected) {
                        final error = snapshot.error;
                        return _panel('Research service unavailable', [
                          Text(error is ResearchConnectionException
                              ? error.message
                              : 'The research response could not be verified. Check the backend version, model ID, units and SHAP validation. No substitute result is shown.'),
                          const SizedBox(height: 8),
                          const Text('The UCI assessment service is unchanged.'),
                          Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(onPressed: _retry, child: const Text('Retry'))),
                        ]);
                      }
                      final e = snapshot.data!;
                      final overview = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _prediction(e),
                        const SizedBox(height: 16),
                        _probabilities(e),
                        const SizedBox(height: 16),
                        _measurements(e),
                      ]);
                      if (!wide) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          overview,
                          const SizedBox(height: 16),
                          _explanation(e),
                        ]);
                      }
                      return Row(
                          key: const ValueKey('research-wide-layout'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: overview),
                            const SizedBox(width: 24),
                            Expanded(flex: 6, child: _explanation(e)),
                          ]);
                    }),
                const SizedBox(height: 20),
                _limitations(),
              ]),
            )),
          ]);
        }),
      );

  Widget _warnings(double side, bool wide) {
    final purpose = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Experimental research model', style: AppTextStyles.labelLg.copyWith(color: AppColors.primaryDark)),
    ]);
    final units = Text('Glucose: provisionally mmol/L. Source unit labels conflict; values are unchanged.',
        style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant));
    return Container(
      width: double.infinity,
      color: AppColors.brandTint,
      padding: EdgeInsets.symmetric(horizontal: side, vertical: 12),
      child: wide
          ? Row(children: [Expanded(child: purpose), const SizedBox(width: 32), Expanded(child: units)])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [purpose, const SizedBox(height: 6), units]),
    );
  }

  Widget _selector() => LayoutBuilder(builder: (context, bounds) {
        final columns = bounds.maxWidth >= 720
            ? 6
            : bounds.maxWidth >= 430
                ? 3
                : 2;
        final width = (bounds.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (var index = 0; index < ResearchDemoClient.exampleIds.length; index++)
            SizedBox(
                width: width,
                child: Semantics(
                  selected: ResearchDemoClient.exampleIds[index] == _selected,
                  child: OutlinedButton(
                    key: ValueKey('select-${ResearchDemoClient.exampleIds[index]}'),
                    onPressed: () => _select(ResearchDemoClient.exampleIds[index]),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      foregroundColor: ResearchDemoClient.exampleIds[index] == _selected
                          ? AppColors.primaryDark
                          : AppColors.onSurfaceVariant,
                      backgroundColor: ResearchDemoClient.exampleIds[index] == _selected
                          ? AppColors.primarySoft
                          : AppColors.surfaceLowest,
                      side: BorderSide(
                          color:
                              ResearchDemoClient.exampleIds[index] == _selected ? AppColors.primary : AppColors.border,
                          width: ResearchDemoClient.exampleIds[index] == _selected ? 2 : 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          if (ResearchDemoClient.exampleIds[index] == _selected) const Icon(Icons.check, size: 18),
                          Text('Example ${ResearchDemoClient.exampleIds[index]}'),
                        ]),
                  ),
                )),
        ]);
      });

  Widget _prediction(ResearchExample e) => _panel('Example ${e.id} · Held-out set', [
        LayoutBuilder(builder: (context, bounds) {
          final labels = [
            _labelCard('Dataset label', _riskName(e.datasetLabel), 'Supplied research classification'),
            _labelCard('Model prediction', _riskName(e.prediction), 'Output of this experimental model'),
          ];
          if (bounds.maxWidth < 400 || MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [labels[0], const SizedBox(height: 8), labels[1]]);
          }
          return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: labels[0]),
            const SizedBox(width: 12),
            Expanded(child: labels[1]),
          ]));
        }),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(e.datasetLabel == e.prediction ? Icons.check_circle_outline : Icons.compare_arrows,
              size: 20, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  e.datasetLabel == e.prediction
                      ? 'Prediction matches the supplied dataset label.'
                      : 'Prediction differs from the supplied dataset label.',
                  style: AppTextStyles.labelMd)),
        ]),
        const SizedBox(height: 8),
        Text('Dataset labels are not clinically verified outcomes.', style: AppTextStyles.bodySm),
      ]);

  Widget _labelCard(String label, String value, String note) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.labelMd),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.headlineSm),
          const SizedBox(height: 4),
          Text(note, style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        ]),
      );

  Widget _probabilities(ResearchExample e) => _panel('Model probabilities', [
        for (final label in ['low risk', 'mid risk', 'high risk'])
          Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Semantics(
                label: '${_riskName(label)} probability',
                value: '${(e.probabilities[label]! * 100).toStringAsFixed(2)} percent',
                child: ExcludeSemantics(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _row(_riskName(label), '${(e.probabilities[label]! * 100).toStringAsFixed(2)}%'),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                      value: e.probabilities[label],
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: const {
                        'low risk': AppColors.riskLow,
                        'mid risk': AppColors.riskModerateText,
                        'high risk': AppColors.riskHigh
                      }[label],
                      backgroundColor: AppColors.surfaceContainer),
                ])),
              )),
        Text('Model probabilities describe these dataset classes, not a clinically calibrated chance of complications.',
            style: AppTextStyles.bodySm),
      ]);

  Widget _measurements(ResearchExample e) => _panel('Fixed measurements · read only', [
        _row('Age', '${e.inputs['age']!.toStringAsFixed(0)} years'),
        _row('Blood pressure',
            '${e.inputs['systolic_bp']!.toStringAsFixed(0)} / ${e.inputs['diastolic_bp']!.toStringAsFixed(0)} mmHg'),
        _row('Glucose', '${e.inputs['blood_glucose_mmol_l']} mmol/L (provisional)'),
        _row('Temperature',
            '${e.temperatureF.toStringAsFixed(1)} °F = ${e.inputs['body_temperature_c']!.toStringAsFixed(2)} °C'),
        _row('Heart rate', '${e.inputs['heart_rate']!.toStringAsFixed(0)} bpm'),
      ]);

  Widget _explanation(ResearchExample e) {
    final entries = e.contributions.entries.toList()..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final extent = entries.fold(0.0, (largest, entry) => math.max(largest, entry.value.abs()));
    final positives = entries.where((entry) => entry.value > 1e-12).toList();
    final negatives = entries.where((entry) => entry.value < -1e-12).toList();
    final summary = [
      if (positives.isNotEmpty)
        '${_featureName(positives.first.key)} contributes most toward ${_riskName(e.prediction)} (${_points(positives.first.value)} pp).',
      if (negatives.isNotEmpty)
        '${_featureName(negatives.first.key)} contributes most against it (${_points(negatives.first.value)} pp).',
      if (positives.isEmpty && negatives.isEmpty)
        'The measurements do not shift this prediction from the model baseline.',
    ].join(' ');
    return _panel('SHAP explanation · ${_riskName(e.prediction)}', [
      Text(summary, style: AppTextStyles.bodyMd),
      const SizedBox(height: 10),
      const Text('SHAP explains this model’s prediction, not medically established causes. '
          'A contribution shows how a feature shifts the predicted class probability relative to the model baseline.'),
      const SizedBox(height: 16),
      _row('Baseline probability', '${(e.baseValue * 100).toStringAsFixed(2)}%'),
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 4, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.arrow_back, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('Against prediction', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Supports prediction', style: AppTextStyles.labelSm.copyWith(color: AppColors.primaryDark)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryDark),
        ]),
      ]),
      const SizedBox(height: 8),
      for (final entry in entries) _contribution(entry.key, entry.value, extent),
      const SizedBox(height: 8),
      _row('Baseline + contributions',
          '${((e.baseValue + e.contributions.values.fold(0.0, (a, b) => a + b)) * 100).toStringAsFixed(2)}%'),
      const Text(
          'Equals the predicted-class probability before display rounding. Bars share a scale; values are percentage points (pp).'),
    ]);
  }

  Widget _contribution(String feature, double value, double extent) {
    final fraction = extent == 0 ? 0.0 : (value.abs() / extent).clamp(0.0, 1.0);
    return Semantics(
      label: '${_featureName(feature)}, ${_points(value)} percentage points, '
          '${value < 0 ? 'against' : value > 0 ? 'supports' : 'no shift to'} predicted class',
      child: ExcludeSemantics(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _row(_featureName(feature), '${_points(value)} pp'),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
                child: Container(
                    height: 12,
                    color: AppColors.surfaceLow,
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                        widthFactor: value < 0 ? fraction : 0,
                        child: Container(height: 8, color: AppColors.shapNegative)))),
            Container(width: 1, height: 20, color: AppColors.outline),
            Expanded(
                child: Container(
                    height: 12,
                    color: AppColors.surfaceLow,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                        widthFactor: value > 0 ? fraction : 0,
                        child: Container(height: 8, color: AppColors.shapPositive)))),
          ]),
        ]),
      )),
    );
  }

  Widget _limitations() => _panel('Research limitations', [
        const Text('Glucose is provisionally mmol/L: the source documentation contains conflicting unit labels. '
            'No glucose conversion is applied. Temperature is converted from °F to °C for this model.'),
        const SizedBox(height: 8),
        const Text(
            'Clinical validity has not been established. These are not a representative evaluation sample and do not establish superiority over the UCI model. '
            'The dataset term “mid risk” is displayed as Moderate Risk.'),
        const SizedBox(height: 10),
        Text(ResearchDemoClient.modelId, style: AppTextStyles.bodySm),
      ]);

  static String _riskName(String label) =>
      const {'low risk': 'Low Risk', 'mid risk': 'Moderate Risk', 'high risk': 'High Risk'}[label]!;
  static String _featureName(String feature) => const {
        'age': 'Age',
        'systolic_bp': 'Systolic BP',
        'diastolic_bp': 'Diastolic BP',
        'blood_glucose_mmol_l': 'Glucose (provisional mmol/L)',
        'body_temperature_c': 'Temperature (°C)',
        'heart_rate': 'Heart rate',
      }[feature]!;
  static String _points(double value) =>
      '${value >= 0 ? '+' : ''}${(value * 100).toStringAsFixed(value != 0 && value.abs() < .0001 ? 4 : 2)}';

  Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [Text(label), Text(value, style: AppTextStyles.labelLg)]));

  Widget _panel(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(title, style: AppTextStyles.titleMd), const SizedBox(height: 14), ...children]),
      );
}
