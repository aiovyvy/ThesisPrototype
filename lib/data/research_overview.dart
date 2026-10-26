import 'package:flutter/material.dart';

import '../models/research.dart';

/// Rounded snapshots of saved locked-test evaluations, not clinical metrics.
/// Sources: ml_model/uci/reports/final_model/experiment_metadata.json and
/// ml_model/reports/notebook_04/experiment_metadata.json. Tests check these
/// values against both metadata and saved predictions.
class ResearchOverview {
  ResearchOverview._();

  static const models = [
    ModelInfo(
      name: 'UCI assessment prototype',
      subtitle: 'Random Forest (UCI)',
      description: 'The assessment workflow sends six indicators to the UCI API when trained-model mode is enabled. '
          'It returns Low, Moderate or High Risk probabilities and a SHAP explanation. '
          'Without that mode, assessments use a simulated classifier, not the trained model.',
      evaluation: 'Saved locked-test evaluation: 92 records, separate from 359 training records '
          '(451 processed records). Groups keep identical six-indicator combinations together, so they do not cross splits; '
          'this does not establish patient or site independence. '
          'The model missed 8 of the 23 records labelled high risk.',
      metrics: {'Accuracy': '69.6%', 'Macro F1': '65.1%', 'High-risk recall': '65.2%'},
    ),
    ModelInfo(
      name: 'Research Demonstration',
      subtitle: 'Experimental research model · Hossain 6,039 records',
      description: 'A separate Random Forest service shows only six fixed held-out examples. '
          'There is no measurement entry or save-to-history option. Dataset labels and model predictions '
          'are shown separately, including examples where they differ.',
      evaluation: 'Saved held-out evaluation: 1,213 records, separate from 4,826 training records '
          '(6,039 processed records). Groups separate identical six-indicator combinations. '
          'The six displayed examples were deliberately selected to show matches and errors; '
          'they are not a representative evaluation sample.',
      metrics: {'Accuracy': '92.9%', 'Macro F1': '92.9%', 'High-risk recall': '86.5%'},
    ),
  ];

  static const pipeline = [
    PipelineStage(
      title: 'Enter synthetic demonstration measurements',
      description: 'Age, systolic and diastolic blood pressure, blood glucose, temperature and heart rate. '
          'Gestational age is context only, not a model input.',
      icon: Icons.edit_note_outlined,
    ),
    PipelineStage(
      title: 'Check inputs and units',
      description: 'The assessment form validates entries and converts display units to the UCI model units: '
          'glucose in mmol/L and temperature in °F. The research examples use a separate mapping.',
      icon: Icons.tune,
    ),
    PipelineStage(
      title: 'Receive the model prediction',
      description: 'In trained-model mode, the UCI API runs its saved Random Forest. '
          'A connection error offers retry; it does not substitute a simulated prediction.',
      icon: Icons.account_tree_outlined,
    ),
    PipelineStage(
      title: 'Review the explanation and session history',
      description: 'Review the predicted category, probabilities and six SHAP contributions. '
          'Assessment results can be saved in temporary session history. '
          'Fixed research examples cannot be saved there.',
      icon: Icons.insights_outlined,
    ),
  ];
}
