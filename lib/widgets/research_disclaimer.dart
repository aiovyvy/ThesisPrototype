import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

/// Mode-independent research notice. Place once in each screen's scrollable
/// content; model-specific and synthetic-data warnings remain separate.
class ResearchDisclaimer extends StatelessWidget {
  const ResearchDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        // Full-width text keeps the notice compact on small screens at 200%.
        child: Text(AppStrings.researchDisclaimer,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurface)),
      );
}
