# AIOVY maternal health research prototype

AIOVY is a Flutter and FastAPI thesis prototype for exploring maternal health risk classification and SHAP explanations. **It is not a clinically approved diagnostic system. Do not use its outputs for clinical decisions.** Use synthetic inputs for assessments; the separate research page serves only six fixed, non-identifiable public dataset examples.

The thesis investigates Logistic Regression, Random Forest and XGBoost offline. **Only Random Forest is integrated into the trained-model workflows.** Starting Flutter without `USE_API=true` selects a simulated classifier instead.

## Implemented workflows

| | UCI assessment prototype | Experimental Research Demonstration |
|---|---|---|
| Flutter entry | Home → assessment → result → SHAP; optional session-history save | Settings → Research Demonstration; public web route |
| Backend | `ml_model/uci/api/main.py`, port 8000 | `ml_model/research_demo/main.py`, port 8001 |
| Saved model | `ml_model/uci/models/aiovy_uci_random_forest.joblib` | `ml_model/models/aiovy_random_forest.joblib` |
| Identity | `Random Forest (UCI)` | `hossain_6039_rf_experimental_v1` |
| Inputs | Six form indicators; synthetic inputs only for this prototype | R1–R6 only; no arbitrary measurements, upload or patient-history save |
| Model units | Glucose mmol/L; temperature °F | Glucose provisionally mmol/L, unchanged; temperature °F → °C |
| Output | Low/Moderate/High probabilities and predicted-class SHAP | Separate dataset label and prediction, probabilities, predicted-class SHAP and baseline |

The clients, mappings and backend applications are separate. Research does not use the assessment classifier interface or patient repository. Neither service silently substitutes simulated results when unavailable. Dataset `mid risk` is displayed as Moderate Risk; each backend preserves its own class mapping.

Other implemented features include assessment validation and unit settings, synthetic patient listings and temporary history, retry, logout/session clearing, responsive research examples, and **How AIOVY Works**. Seeded patient records and their explanations are simulated even when new assessments use the UCI API.

## Saved evaluation evidence

These are **dataset-label agreement scores**, not clinically verified outcomes or prospective clinical validation. Values are rounded to one decimal percent from saved final evaluations, not cross-validation results.

| Saved Random Forest evaluation | Processed / training / test records | Accuracy | Macro F1 | High-risk recall |
|---|---|---|---|---|
| UCI | 451 / 359 / 92 | 69.6% | 65.1% | 65.2% |
| Hossain research | 6,039 / 4,826 / 1,213 | 92.9% | 92.9% | 86.5% |

Sources:

- [UCI final metadata](ml_model/uci/reports/final_model/experiment_metadata.json), [test metrics](ml_model/uci/reports/final_model/heldout_test_metrics.csv), and [saved predictions](ml_model/uci/reports/final_model/heldout_test_predictions.csv).
- [Research final metadata](ml_model/reports/notebook_04/experiment_metadata.json), [test metrics](ml_model/reports/notebook_04/heldout_test_metrics.csv), and [saved predictions](ml_model/reports/notebook_04/heldout_test_predictions.csv).
- [UCI selection record](ml_model/uci/reports/model_selection.json): highest mean high-risk recall across repeated nested cross-validation, with macro F1 as tie-break. This does not imply superiority on every metric.

Accuracy measures matching labels. Macro F1 gives each category equal weight when combining precision and recall. High-risk recall measures the fraction of high-risk-labelled records predicted high risk. UCI missed 8 of 23 high-risk-labelled test records; the research model missed 54 of 401. Different datasets and splits prevent these scores from establishing superiority between the models.

Splits group identical six-feature combinations to prevent overlap; this does not prove patient, visit or site independence. UCI contains conflicting labels for some identical feature combinations. The six research examples are held out and deliberately selected to show matches and errors; they are not a representative performance sample.

SHAP describes how inputs move the **model's predicted-category probability** from its baseline. Both APIs check that baseline plus contributions reconstructs the prediction. This is software consistency, not clinical validation. SHAP does not establish medical causes, treatment recommendations or the effect of changing a measurement. Model probabilities are not verified probabilities of medical outcomes.

## Local setup (Windows PowerShell)

Use a Flutter SDK compatible with `pubspec.yaml` (Dart >=3.5 and <4.0), Chrome, and Python 3.12 with the artifact-compatible versions in [requirements.txt](ml_model/uci/requirements.txt). Saved artifacts are present; **do not execute training notebooks to launch the app**.

From the project root, install dependencies only when setting up a new environment:

```powershell
Set-Location -LiteralPath 'C:\Users\Kenjo Condez\Downloads\aiovy-redesign'
flutter pub get
# Only if ml_model/uci/.venv does not exist:
py -3.12 -m venv ml_model/uci/.venv
# Install only when needed; otherwise reuse the existing compatible environment:
& .\ml_model\uci\.venv\Scripts\python.exe -m pip install -r .\ml_model\uci\requirements.txt
```

The existing platform folders should be reused. Keep each server terminal open. Sharing Python dependencies does not combine the API applications.

### Terminal 1: UCI assessment API

```powershell
Set-Location -LiteralPath 'C:\Users\Kenjo Condez\Downloads\aiovy-redesign\ml_model\uci'
& .\.venv\Scripts\python.exe -B -m uvicorn api.main:app --host 127.0.0.1 --port 8000
```

### Terminal 2: experimental research API

Run from the project root, not `ml_model/uci`:

```powershell
Set-Location -LiteralPath 'C:\Users\Kenjo Condez\Downloads\aiovy-redesign'
& .\ml_model\uci\.venv\Scripts\python.exe -B -m uvicorn ml_model.research_demo.main:app --host 127.0.0.1 --port 8001
```

Wait for application startup to complete. Missing dependencies can indicate the wrong Python executable; import failures can indicate the wrong directory. Do not terminate unrelated processes if a port is occupied.

### Terminal 3: Flutter web

```powershell
Set-Location -LiteralPath 'C:\Users\Kenjo Condez\Downloads\aiovy-redesign'
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080 --no-pub --dart-define=USE_API=true --dart-define=API_URL=http://127.0.0.1:8000 --dart-define=RESEARCH_API_URL=http://127.0.0.1:8001
```

Alternatively replace `-d chrome` with `-d web-server` and open the printed URL. Restart Flutter after changing build-time definitions; Chrome refresh does not change compiled configuration. Plain `flutter run` selects simulated assessments. The default UCI address is the Android-emulator alias `10.0.2.2`, so set `API_URL` explicitly for Chrome.

Check services independently:

```powershell
Invoke-RestMethod 'http://127.0.0.1:8000/health'
Invoke-RestMethod 'http://127.0.0.1:8001/health'
Invoke-RestMethod 'http://127.0.0.1:8001/openapi.json'
1..6 | ForEach-Object { Invoke-RestMethod "http://127.0.0.1:8001/research/examples/R$_" }
```

Both expose `/docs`. Research offers fixed GET endpoints, rejects arbitrary bodies/query parameters, and has no `/classify`. See the [UCI API guide](ml_model/uci/api/README.md) and [research guide](ml_model/research_demo/README.md) for contracts and troubleshooting.

## Session, privacy and platform limitations

- Demo login accepts non-empty fields; prefilled credentials are for presentation. There is no real identity verification, account recovery or server-validated session.
- Session-entered patient records exist only in memory. Refresh/restart loses them; logout clears them and restores synthetic seed records. This is not durable medical-record storage.
- Dashboard, Patients, Profile and Settings use a **DEMO-ONLY** UI guard. Web sign-in stores a fixed, non-secret `sessionStorage` marker (`aiovy.demo-only-mode=enabled-v1`) so those safe pages can reopen in the same tab after refresh. This is not real authentication, an API token or a security boundary. Mobile keeps its in-memory navigation.
- Research is public and read-only: `http://127.0.0.1:8080/#/research-demonstration/R4` restores R4 on refresh. Back/Forward restores selection. URLs contain fixed public IDs, not session records.
- How AIOVY Works has its own guarded `/#/how-aiovy-works` URL, including when opened from a live SHAP explanation. It refreshes independently of that assessment. Intro, onboarding and login also have safe URLs (`/#/`, `/#/onboarding`, `/#/login`); onboarding refresh starts at its first slide. See the [visible-page routing audit](docs/web-routing-audit.md).
- Only that demo-mode marker is stored: no credentials, tokens, patient identifiers, measurements, predictions, SHAP or history. `/assessment` refresh/history opens a blank new form with a draft/selection reset notice. `/patients` restores the list using the current in-memory repository (synthetic seeds only after a full refresh). `/patient-details` falls back to Patients when its selection is lost. `/processing`, `/result` and `/explanation` still fall back to Dashboard; no result is recreated. In-app Back retains the live stack. Logout clears the marker and entered records and gates protected history. See [session details](docs/demo-browser-session.md) and the [patient workflow audit and Chrome checklist](docs/patient-workflow-audit.md).
- APIs have no authentication; local HTTP is unencrypted. CORS is not access control. Keep services local and do not enter real patient information. Error-log privacy checks are not a complete security audit. See [security limitations](docs/security-limitations.md).
- Mobile retains its navigation. Widget tests do not establish Android/device networking. Debug/profile manifests have internet permission; the main release manifest lacks it, and release uses debug signing. The UCI client requires HTTPS in release. Validate network policy, permissions, host binding and firewall before Android presentation. Phones need the PC's reachable LAN address; emulator addresses and PC loopback are not interchangeable.
- Inter fonts use `google_fonts`; rehearse offline availability. Neither model has established clinical approval, independent prospective validation, or generalization to the intended population.

## Architecture

```text
lib/
  screens/assessment, processing, result, shap/  Assessment flow
  screens/research/                            Informational page and fixed-example view
  services/api_risk_classifier.dart             UCI POST /classify client
  services/mock_risk_classifier.dart            Simulated default classifier
  services/research_demo_client.dart            Separate fixed-example GET client
  data/repositories/                           In-memory patients and settings
  data/research_overview.dart                   Saved informational evaluation summaries
  navigation/                                  Mobile navigation and guarded web router
  state/app_scope.dart                         Shared assessment dependencies
ml_model/uci/                                  UCI artifact, API and reports
ml_model/research_demo/                        Fixed-example API, provenance manifest and tests
ml_model/models/, reports/notebook_04/          Hossain artifact and saved evaluations
test/                                         Flutter unit, widget and router checks
```

## Sources and unresolved provenance

- Ahmed, M. (2020). *Maternal Health Risk* [Dataset]. UCI Machine Learning Repository. [DOI: 10.24432/C5DP5D](https://doi.org/10.24432/C5DP5D), CC BY 4.0. The [UCI entry](https://archive.ics.uci.edu/dataset/863/maternal+health+risk) lists 1,013 source records, glucose mmol/L and temperature °F; the integrated artifact uses the local 451-record processed subset. Its introductory paper is Ahmed, Kashem, Rahman and Khatun (2020), *Review and Analysis of Risk Factor of Maternal Health in Remote Area Using the Internet of Things (IoT)*, Lecture Notes in Electrical Engineering 632. Risk-label generation/adjudication is insufficiently documented for clinical claims.
- Hossain, Mohammad Mobarak (2025). *Maternal health risk data*. Mendeley Data V1. [DOI: 10.17632/ckhgtgdg4f.1](https://data.mendeley.com/datasets/ckhgtgdg4f/1), CC BY 4.0. The local processed subset has 6,039 records; the original local raw export is absent.
- Hossain, M. M., Nayan, N. M. and Kashem, M. A. (2026). *A comprehensive maternal health risk prediction dataset from IoT-enabled medical cyber-physical systems in developing countries: supporting machine learning and deep learning applications for clinical decision support*. BMC Medical Informatics and Decision Making 26, 79. [DOI: 10.1186/s12911-026-03343-1](https://doi.org/10.1186/s12911-026-03343-1).
- Lundberg, S. M. and Lee, S.-I. (2017). *A Unified Approach to Interpreting Model Predictions*. Advances in Neural Information Processing Systems 30. [Paper](https://proceedings.neurips.cc/paper/2017/hash/8a20a8621978632d76c43dfd28b67767d-Abstract.html).

The Hossain original glucose header says mg/dL; publication Table 3 supports mmol/L, while other tables have conflicting labels. **mmol/L is provisional, not author-confirmed. Glucose is not silently converted.** A corrected dictionary, original export/unit history and verified original version/checksum are missing; the publication references V2 while the cited dataset is V1. Public descriptions of validated records do not establish clinical validation of AIOVY. Automated label rules, expert-subset adjudication, measurement traceability and patient/visit/site linkage cannot be fully verified locally. See [research provenance notes](ml_model/research_demo/README.md#source-and-unresolved-limitations).

## Verification

From the project root, with dependencies available:

```powershell
flutter analyze --no-pub
flutter test --no-pub
& .\ml_model\uci\.venv\Scripts\python.exe -B -m unittest ml_model.research_demo.test_research_demo -v
```

The backend suite checks six examples, artifact/data hashes, held-out membership, units, classes, probabilities/SHAP, input restrictions, and all 92 saved UCI predictions through its unchanged classifier. From `ml_model/uci`, run `& .\.venv\Scripts\python.exe -B -m unittest api.test_api_privacy -v` for privacy regressions.

Flutter tests cover routing/guards, layouts, assessment/history, explanations and saved informational metrics. Standard backend tests use in-process HTTP; widget/router tests are not live Chrome or Android tests. Optional visual-export and live recovery tests are skipped unless enabled; see the research guide. Passing tests establishes software consistency, not clinical safety. Rehearse the complete defense flow on the intended browser/device and verify the API mode before presenting.
