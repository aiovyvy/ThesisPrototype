/// App-wide copy that appears on several screens.
class AppStrings {
  AppStrings._();

  static const String appName = 'AIOVY';
  static const String tagline = 'Calm intelligence for maternal care';
  static const String wordmarkSub = 'MATERNAL CARE INTELLIGENCE';
  static const String versionShort = 'AIOVY v1.0 · Thesis Prototype';
  static const String thesisTitle = 'AIOVY: Maternal Health Risk Classification Using Logistic Regression, '
      'Random Forest and XGBoost with Explainable AI';

  static const String decisionNotice = 'AIOVY provides machine-learning decision support and does not replace '
      'professional clinical judgment or comprehensive diagnostic evaluation.';

  static const String researchDisclaimer = 'Research demonstration only. Not clinically validated. '
      'Does not replace professional clinical judgment. Do not use for clinical decisions.';

  /// Shown on every result produced by the built-in demo classifier.
  static const String demoOutputTag = 'Simulated · demo classifier, not the trained model';

  /// Short marker for simulated results in lists that may also contain
  /// trained-model results.
  static const String simulatedShort = 'Simulated';

  /// Where real patient data could be typed: the assessment form.
  static const String syntheticDataOnly =
      'Synthetic test data only. Do not enter real patient information: this prototype has no '
      'security or ethics approval for patient data.';

  /// The sign-in has no real authentication.
  static const String demoAccess = 'DEMO ACCESS';
  static const String demoAccessNote =
      'There is no real authentication: any non-empty email and password opens the app. '
      'Use synthetic records only.';
  static const String pendingEvaluation = 'Pending Evaluation';
}
