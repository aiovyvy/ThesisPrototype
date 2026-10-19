import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/maternal_indicators.dart';
import 'indicator_spec.dart';

/// Everything one indicator input needs from the form.
class IndicatorFieldData {
  const IndicatorFieldData({
    required this.spec,
    required this.controller,
    required this.focusNode,
    required this.status,
    required this.showErrors,
    required this.onChanged,
    required this.onSubmitted,
    required this.isLast,
    this.crossCheckMessage,
  });

  final IndicatorSpec spec;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FieldStatus status;

  /// Errors are shown once the field has text or the user tried to submit.
  final bool showErrors;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool isLast;
  final String? crossCheckMessage;

  Indicator get indicator => spec.indicator;
  bool get isError => showErrors && status != FieldStatus.valid;
  bool get isValid => status == FieldStatus.valid;

  String? get errorText {
    if (!showErrors) return null;
    return switch (status) {
      FieldStatus.valid => null,
      FieldStatus.empty => 'Required · enter ${spec.rangeText}',
      FieldStatus.invalidNumber => spec.decimal ? 'Enter a number, e.g. ${spec.fmt(spec.min)}' : 'Enter a whole number',
      FieldStatus.outOfRange => 'Check value · expected ${spec.rangeText}',
      FieldStatus.crossCheck => crossCheckMessage,
    };
  }
}

/// Plain-language names for the form. Kept here (not in the model) so the
/// model's labels used elsewhere are unchanged.
String fieldLabel(Indicator i) => switch (i) {
      Indicator.age => 'Age',
      Indicator.systolic => 'Systolic',
      Indicator.diastolic => 'Diastolic',
      Indicator.bloodGlucose => 'Blood glucose',
      Indicator.bodyTemperature => 'Body temperature',
      Indicator.heartRate => 'Heart rate',
    };

/// Short clarifying hint shown under the label, or null.
String? fieldHint(Indicator i) => switch (i) {
      Indicator.systolic => 'Top number',
      Indicator.diastolic => 'Bottom number',
      // Midwives also measure fetal heart rate; the model input is the mother's.
      Indicator.heartRate => "Mother's pulse, not fetal heart rate",
      _ => null,
    };

/// Label (+ hint and range) on the left, value on the right. Stacks on very
/// narrow screens so long labels never squeeze the input.
class IndicatorFieldRow extends StatelessWidget {
  const IndicatorFieldRow({super.key, required this.data});

  final IndicatorFieldData data;

  @override
  Widget build(BuildContext context) {
    final hint = fieldHint(data.indicator);
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(data: data, text: fieldLabel(data.indicator)),
        if (hint != null) ...[
          const SizedBox(height: 1),
          Text(hint, style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
        const SizedBox(height: 4),
        _Helper(data: data),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 260) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [label, const SizedBox(height: 8), _NumberInput(data: data)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(padding: const EdgeInsets.only(top: 2), child: label),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 136, child: _NumberInput(data: data)),
          ],
        );
      },
    );
  }
}

/// Systolic and diastolic side by side, read as one value ("142 / 92").
class BloodPressureFields extends StatelessWidget {
  const BloodPressureFields({super.key, required this.systolic, required this.diastolic});

  final IndicatorFieldData systolic;
  final IndicatorFieldData diastolic;

  Widget _column(IndicatorFieldData d) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(data: d, text: fieldLabel(d.indicator)),
          Text(fieldHint(d.indicator)!, style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          _NumberInput(data: d),
          const SizedBox(height: 6),
          _Helper(data: d),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_column(systolic), const SizedBox(height: AppSpacing.md), _column(diastolic)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _column(systolic)),
            // The slash sits level with the inputs, echoing how BP is written.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 52, 8, 0),
              child: ExcludeSemantics(
                child: Text('/', style: AppTextStyles.headlineMd.copyWith(color: AppColors.outline)),
              ),
            ),
            Expanded(child: _column(diastolic)),
          ],
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.data, required this.text});

  final IndicatorFieldData data;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text(text, style: AppTextStyles.labelLg)),
        if (data.isValid || data.isError) ...[
          const SizedBox(width: 6),
          ExcludeSemantics(
            child: Icon(
              data.isValid ? Icons.check_circle : Icons.error,
              size: 16,
              color: data.isValid ? AppColors.riskLow : AppColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// The expected range, replaced by the validation message when needed.
class _Helper extends StatelessWidget {
  const _Helper({required this.data});

  final IndicatorFieldData data;

  @override
  Widget build(BuildContext context) {
    final err = data.errorText;
    if (err != null) {
      return Semantics(
        liveRegion: true,
        child: Text(err, style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.error)),
      );
    }
    return ExcludeSemantics(
      child: Text(
        data.spec.rangeText,
        style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.outline),
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({required this.data});

  final IndicatorFieldData data;

  static OutlineInputBorder _border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    final spec = data.spec;
    final err = data.isError;
    final hint = fieldHint(data.indicator);
    return Semantics(
      label: '${fieldLabel(data.indicator)}${hint != null ? ', $hint' : ''}, ${spec.unit}, expected ${spec.rangeText}',
      child: SizedBox(
        height: AppSpacing.inputHeight,
        child: TextField(
          controller: data.controller,
          focusNode: data.focusNode,
          onChanged: data.onChanged,
          onSubmitted: (_) => data.onSubmitted(),
          keyboardType: spec.decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
          textInputAction: data.isLast ? TextInputAction.done : TextInputAction.next,
          // Keeps the field clear of the sticky "Assess risk" bar when scrolled
          // into view above the keyboard.
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          inputFormatters: [
            FilteringTextInputFormatter.allow(spec.decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]')),
            LengthLimitingTextInputFormatter(5),
          ],
          style: AppTextStyles.metric,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: '—',
            hintStyle: AppTextStyles.metric.copyWith(color: AppColors.outlineVariant),
            // suffixText only appears once the field is focused or filled; the
            // unit should always be visible, so it is drawn as an icon slot.
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(spec.unit, style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: err ? AppColors.errorTint : AppColors.surfaceLow,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: _border(err ? AppColors.error : AppColors.fieldBorder, err ? 1.5 : 1),
            focusedBorder: _border(err ? AppColors.error : AppColors.primary, 2),
          ),
        ),
      ),
    );
  }
}
