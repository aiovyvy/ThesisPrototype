import 'package:flutter/material.dart';

/// Informational content for an integrated workflow, not live results.
@immutable
class ModelInfo {
  const ModelInfo({
    required this.name,
    required this.subtitle,
    required this.description,
    required this.evaluation,
    required this.metrics,
  });

  final String name;
  final String subtitle;
  final String description;
  final String evaluation;
  final Map<String, String> metrics;
}

@immutable
class PipelineStage {
  const PipelineStage({required this.title, required this.description, required this.icon});

  final String title;
  final String description;
  final IconData icon;
}
