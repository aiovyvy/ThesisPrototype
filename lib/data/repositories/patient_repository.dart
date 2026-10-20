import 'package:flutter/foundation.dart';

import '../../models/assessment.dart';
import '../../models/patient.dart';
import '../../models/risk_level.dart';
import '../mock/mock_patients.dart';

/// In-memory patient store. Replace the body of these methods with a local
/// database or API calls later – screens only talk to this class.
///
/// Privacy: nothing is written to disk, so everything entered is lost when
/// the app closes. Within a running app, [clearSession] removes everything
/// saved since start-up (used on sign-out), leaving only the synthetic
/// demo records.
class PatientRepository extends ChangeNotifier {
  PatientRepository({List<Patient>? seed})
      : _seed = seed,
        _patients = _fresh(seed);

  /// A custom seed (tests), or null for the synthetic demo cohort.
  final List<Patient>? _seed;
  final List<Patient> _patients;

  /// IDs of assessments saved during this session (not part of the seed).
  final Set<String> _sessionIds = {};

  static List<Patient> _fresh(List<Patient>? seed) =>
      seed == null ? MockPatients.build() : [for (final p in seed) _copy(p)];

  static Patient _copy(Patient p) => Patient(
        id: p.id,
        age: p.age,
        gestationalAge: p.gestationalAge,
        clinicalNote: p.clinicalNote,
        assessments: List.of(p.assessments),
      );

  /// Number of assessments saved since start-up or the last [clearSession].
  int get sessionAssessmentCount => _sessionIds.length;

  /// Discards every assessment and patient saved during this session and
  /// restores the original synthetic records. Nothing is kept anywhere else
  /// (there is no disk or server copy to delete).
  void clearSession() {
    _patients
      ..clear()
      ..addAll(_fresh(_seed));
    _sessionIds.clear();
    notifyListeners();
  }

  List<Patient> get patients {
    final list = List<Patient>.of(_patients);
    list.sort((a, b) {
      final ta = a.latest?.timestamp ?? DateTime(1970);
      final tb = b.latest?.timestamp ?? DateTime(1970);
      return tb.compareTo(ta);
    });
    return List.unmodifiable(list);
  }

  Patient? byId(String id) {
    for (final p in _patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Every assessment across all patients, newest first.
  List<Assessment> get allAssessments {
    final all = [for (final p in _patients) ...p.assessments];
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  List<Assessment> assessmentsOn(DateTime day) => allAssessments
      .where((a) => a.timestamp.year == day.year && a.timestamp.month == day.month && a.timestamp.day == day.day)
      .toList();

  int countByRisk(RiskLevel level) => _patients.where((p) => p.currentRisk == level).length;

  /// Next free demo ID, e.g. "P-0015".
  String nextPatientId() {
    var max = 0;
    for (final p in _patients) {
      final n = int.tryParse(p.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > max) max = n;
    }
    return 'P-${(max + 1).toString().padLeft(4, '0')}';
  }

  /// Saves an assessment, creating the patient record if it is new.
  void saveAssessment(Assessment assessment) {
    var patient = byId(assessment.patientId);
    if (patient == null) {
      patient = Patient(id: assessment.patientId, age: assessment.indicators.age, gestationalAge: null);
      _patients.add(patient);
    }
    patient.age = assessment.indicators.age;
    patient.assessments.removeWhere((a) => a.id == assessment.id);
    patient.assessments.insert(0, assessment);
    patient.assessments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _sessionIds.add(assessment.id);
    notifyListeners();
  }

  bool isSaved(Assessment assessment) =>
      byId(assessment.patientId)?.assessments.any((a) => a.id == assessment.id) ?? false;
}
