# AIOVY Research Demonstration

**Experimental research model. Demonstration only. Must not be used for clinical
decisions. Clinical validity has not been established.**

This standalone FastAPI app serves six fixed, non-identifiable examples from the
Hossain 6,039-record research dataset. Settings > Research Demonstration opens its
read-only screen inside AIOVY. It never calls the UCI classifier, writes patient
records, or accepts measurements. There is no fallback to UCI or simulated output.
The UCI assessment API, Flutter classifier, repository and SHAP flow are unchanged.

## Verified Windows PowerShell launch instructions

Use two separate PowerShell terminals. Keep the backend terminal open. The global
`python` does not contain all model dependencies; use the existing virtual
environment executable below. Imports and model startup were verified with it.

Terminal 1 - research backend (project root, **not** `ml_model/uci`):

```powershell
Set-Location -LiteralPath 'C:\Users\Kenjo Condez\Downloads\aiovy-redesign'
& .\ml_model\uci\.venv\Scripts\python.exe -B -m uvicorn ml_model.research_demo.main:app --host 127.0.0.1 --port 8001
```

Wait for `Application startup complete` and `Uvicorn running on
http://127.0.0.1:8001`. `Ctrl+C` stops it. A missing-module error usually means
another Python environment was used. An import error for `ml_model` usually means
this command was run from the wrong directory. A port-in-use error means another
process owns 8001; inspect it rather than terminating unrelated services.

Health and all six outputs can be checked in another PowerShell terminal:

```powershell
Invoke-RestMethod 'http://127.0.0.1:8001/health'
Invoke-WebRequest 'http://127.0.0.1:8001/docs' -UseBasicParsing | Select-Object StatusCode
Invoke-RestMethod 'http://127.0.0.1:8001/openapi.json'
1..6 | ForEach-Object { Invoke-RestMethod "http://127.0.0.1:8001/research/examples/R$_" }
```

All these endpoints were verified over real HTTP. `/docs` and `/openapi.json`
were previously explicitly disabled (404 even on a healthy service); they are now
enabled. Swagger's browser UI loads its assets from a public CDN. `/health` and
`/openapi.json` do not require that CDN. The OpenAPI schema exposes only fixed
GET endpoints, never a measurements/classification request.

Terminal 2 - verified Flutter web-server launch, then open the printed URL in Chrome:

```powershell
Set-Location -LiteralPath 'C:\Users\Kenjo Condez\Downloads\aiovy-redesign'
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --no-pub --dart-define=USE_API=true --dart-define=API_URL=http://127.0.0.1:8000 --dart-define=RESEARCH_API_URL=http://127.0.0.1:8001
```

Open `http://127.0.0.1:8080/#/research-demonstration/R1` directly, or use the existing
demo sign-in then Profile > Settings > Research Demonstration. To let Flutter launch Chrome directly instead, replace
`-d web-server` with `-d chrome` in that command. The web-server build/HTTP serving
were verified; automated live Chrome interaction was unavailable in this environment.
Restart/rebuild Flutter after changing a `--dart-define`; a browser refresh alone
cannot change a compiled API URL.

The research service uses port **8001**. The existing UCI backend continues
independently on **8000**; it must be started separately with its existing instructions
if you want assessments. The research screen does not need the UCI server.
`API_URL` and `RESEARCH_API_URL` are independent; do not point research at port 8000.
No UCI module is imported by the research service.

Without `RESEARCH_API_URL`, the web client now defaults to `http://127.0.0.1:8001`.
Native builds retain `http://10.0.2.2:8001` for Android emulators. For an emulator,
bind the research server to an interface reachable by the emulator. Loopback on a
phone refers to the phone itself. The local HTTP CORS allowlist covers `localhost`
and `127.0.0.1` with development ports. CORS is not authentication.

The client reports the actual configured address, HTTP status, connection failure,
timeout or a validation failure. Retry issues a fresh GET and never substitutes
UCI or simulated predictions. The previous Retry callback incorrectly returned a
Future from `setState`; this is fixed and covered by a widget regression test.

Only `GET /health`, `GET /research/examples`, `GET /research/examples/R1` through
`/R6`, and FastAPI documentation/schema endpoints exist. Query parameters and
request bodies remain rejected, including on valid example IDs. Unknown IDs and
write methods are rejected. There is no `/classify`, upload, save, or patient
endpoint. Artifact/manifest hash checks and all probability/SHAP checks remain intact.
Results are validated at startup and served from a fixed cache; requests cannot
trigger custom inference. No hosting or deployment is added.

## Public research navigation, refresh and logout

Research Demonstration is a public, read-only route. For example, open
`http://127.0.0.1:8080/#/research-demonstration/R4` to select R4 directly, without
sign-in. The six allowlisted paths end in R1 through R6. The older
`/#/research-demonstration` URL defaults to R1. Invalid research IDs normalize to
R1; they cannot become arbitrary API inputs. Unknown paths and query parameters
cannot introduce patient data or authentication state into the router.

Selecting an example writes only its public ID into the browser URL. Refresh
restores that same example, and Back/Forward restores both selection and result.
This does not require browser storage or a persistent demo session. The public
page renders alone, without a private application shell or Settings page behind
it, and does not depend on the patient repository or UCI classifier. Its Back
button returns to Settings during an active in-memory demo session, or Intro
when there is no session. Mobile keeps its existing push/pop navigation and local
example selection.

Dashboard, Settings, Profile, Patients and the existing assessment/history flows
remain private to the in-memory demo session. Refresh on a protected URL still
requires sign-in before restoring that destination. Logout clears session-entered
records and revokes demo access; browser history cannot restore protected screens
or patient records afterward. The public research page remains available because
it contains only the six fixed public examples, not patient/session records.

No credentials, authentication flags, fake tokens, patient records or other
sensitive state are stored in browser storage. Only allowlisted route names and
fixed example IDs are represented in URLs. The current demo login is not real
authentication; production access control would require server-validated sessions.

## Responsive research view

The screen uses AIOVY typography, rose/sage palette and bordered surfaces. It
stacks panels on mobile/tablet and uses a content area up to 1,200 logical pixels
with side-by-side result and explanation panels on wide screens. All six example
buttons remain available, with a checkmark and border indicating selection.

Dataset labels and model predictions have separate read-only panels and an
explicit match/difference statement. Low, Moderate and High Risk probabilities
have labelled bars, percentages and accessibility semantics. The underlying
`mid risk` class is displayed as Moderate Risk; its encoder/probability mapping
is unchanged. SHAP contributions are sorted by absolute size and shown on a shared
scale to either side of zero, with signed percentage-point values, a plain-language
summary, and baseline reconstruction. This is presentation only: no probabilities,
contributions or fitted model values are changed.

Experimental-use and provisional glucose-unit warnings stay visible above the
scrolling content. SHAP explicitly describes the model prediction, not medically
established causes. Details of the source inconsistencies remain below the panels.

## Artifact and examples inspected before implementation

Model ID: `hossain_6039_rf_experimental_v1`.
Artifact: `ml_model/models/aiovy_random_forest.joblib`, a pipeline containing only
`RandomForestClassifier`, with a fitted label encoder and feature list.
Inspection and test environment: scikit-learn 1.9.1, SHAP 0.52.0, Python 3.12.
The original artifact and datasets are not rewritten or retrained.

`examples.json` records SHA-256 digests for the artifact, processed dataset and
saved held-out predictions. Artifact SHA-256:
`513edbb98a8964e7569f24a34f304eb1c25db7b2a8d4cfc253b4b01877f58d94`.
These hashes identify local research inputs, not the missing original Mendeley CSV.

The root `.gitattributes` pins CRLF checkout endings for the manifest and the two
audited CSV inputs, whose SHA-256 digests cover their exact bytes. This preserves
the audited hashes across Git clones regardless of the local `core.autocrlf`
setting. Do not reformat these files without explicitly reviewing their hashes;
the model artifact and measurement values are not changed by this checkout rule.

The original notebook split is reconstructed using hashes of the ordered six
features and `GroupShuffleSplit(test_size=0.20, random_state=42)`:
4,826 training / 1,213 held-out records, with zero overlapping six-feature groups.
All saved held-out indices and feature values match that reconstruction; the
artifact reproduces all 1,213 saved probability vectors within floating-point
precision. Grouping feature vectors does not establish patient/site independence.

Selection: first correct and first incorrect held-out prediction per supplied
dataset class in encoder order. This deliberately illustrates errors and must not
be used to calculate representative accuracy or compare the UCI model.

| Demo ID | Processed dataset row index (zero based) | Split | Dataset label | Model prediction |
|---|---:|---|---|---|
| R1 | 0 | Held-out | high risk | high risk |
| R2 | 223 | Held-out | high risk | mid risk |
| R3 | 12 | Held-out | low risk | low risk |
| R4 | 4803 | Held-out | low risk | mid risk |
| R5 | 5 | Held-out | mid risk | mid risk |
| R6 | 147 | Held-out | mid risk | high risk |

Indices refer to the **processed** CSV, not original patient IDs or raw CSV row
indices. No names, original identifiers, dates, facilities or patient linkage are
included in the demonstration manifest or responses. The features remain actual
research dataset examples, not newly collected patient data or synthetic records.

## Feature, unit and explanation contract

| Position | Model feature | Unit / treatment |
|---:|---|---|
| 1 | age | years |
| 2 | systolic_bp | mmHg |
| 3 | diastolic_bp | mmHg |
| 4 | blood_glucose_mmol_l | provisionally mmol/L; values unchanged |
| 5 | body_temperature_c | `(temperature_f - 32) * 5 / 9` |
| 6 | heart_rate | bpm |

Fixed example Fahrenheit temperatures are recovered from the processed Celsius
values and rounded to the source's one-decimal precision. Tests compare the
converted values with the saved held-out records to 1e-12 absolute tolerance.
Research units are explicit and independent of the assessment Settings unit toggles.

Class codes are **0 = high risk, 1 = low risk, 2 = mid risk**, verified against
both encoder and estimator. Probabilities are keyed by those dataset label names;
the research flow does not reuse the UCI/app class mapping. Dataset labels are
supplied research classifications, not clinically verified outcomes.

`shap.TreeExplainer` explains the actual predicted class in probability space.
Every result must satisfy `baseline + sum(contributions) = P(predicted class)`
within 1e-6, with finite probabilities in [0,1] summing to one. Startup fails if
checks fail or predictions differ from the saved reference. Flutter independently
validates the model ID, example ID, class, units, probabilities and SHAP sum and
shows an error instead of an unverified result. The screen displays contributions
as signed percentage points and makes no causal or clinical interpretation.

## Source and unresolved limitations

- Hossain, Mohammad Mobarak (2025), *Maternal health risk data*, Mendeley Data,
  V1, DOI [10.17632/ckhgtgdg4f.1](https://data.mendeley.com/datasets/ckhgtgdg4f/1),
  CC BY 4.0. AIOVY's processed subset excludes 64 of 6,103 rows, removes identifiers
  and two features, and converts temperature.
- Hossain, M.M., Nayan, N.M. & Kashem, M.A. (2026), *A comprehensive maternal
  health risk prediction dataset from IoT-enabled medical cyber-physical systems
  in developing countries: supporting machine learning and deep learning
  applications for clinical decision support*, BMC Medical Informatics and Decision
  Making 26, 79. [Publication](https://doi.org/10.1186/s12911-026-03343-1).

The original glucose header says mg/dL; the publication's Table 3 says mmol/L and
matches the example values; Table 4 has a conflicting mmol/mol label with mg/dL
equivalents, while other tables retain mg/dL labels. mmol/L is provisional, not
author-confirmed. No silent glucose conversion is performed. Missing: corrected
data dictionary, original export/unit history and verified original file/version
checksum (the publication references V2; the original local raw file is absent).

The publication describes automated labels checked by experts on a subset. Their
generation rules and adjudication records are not reproduced locally. Measurement
traceability, HbA1c assay details and patient/visit/site linkage remain unresolved.
Clinical validity and generalization to AIOVY's intended population are unestablished.
Neither this demonstration nor its selected examples establish superiority over UCI.

## Automated checks

From the repository root:

```powershell
& ml_model/uci/.venv/Scripts/python.exe -B -m unittest ml_model.research_demo.test_research_demo -v
```

This checks real artifact outputs, source hashes, held-out membership, feature
order, unit conversion, class mapping, probability and SHAP checks, HTTP rejection
of arbitrary inputs, and all **92 existing UCI held-out predictions** through its
unchanged classifier (including its SHAP validation).

Existing UCI privacy/regression tests, from `ml_model/uci`:

```powershell
& .venv/Scripts/python.exe -B -m unittest api.test_api_privacy -v
```

Flutter checks, from the repository root:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

The research tests use ASGI directly, so no new Python packages or running servers
are required. The standard requirements are shared only for installing dependencies,
not for model logic or application state. Do not interpret passing software tests
as clinical validation.

## Verification of public research navigation and responsive UI (2026-10-23)

- Research backend: **10 tests passed** using the real artifact. All six fixed
  examples match their reference predictions/probabilities/SHAP values. Feature
  order, units, class mapping, SHAP reconstruction and fixed-input restrictions
  remain checked. No backend model logic was changed for this UI update.
- Existing UCI privacy/regression tests: **4 passed**. All **92** saved UCI
  predictions/probabilities match to 1e-9 through its unchanged classifier and
  per-request SHAP validation.
- `flutter analyze --no-pub`: **no issues**.
- `flutter test --no-pub`: **108 passed, 4 skipped** (three optional asset/visual
  exports and the separately executed opt-in live HTTP test).
- The opt-in real-HTTP recovery test also passed. It uses a temporary backend on
  18001, checks actual connection refusal followed by a new successful request,
  and stops its own server afterward:

```powershell
flutter test --no-pub test/research_live_test.dart --dart-define=LIVE_RESEARCH_TEST=true
```

Router tests restore each of the six examples from a fresh session, verify public
rendering with no patient repository/AppScope, report selection changes to URLs,
consume simulated Back/Forward events, and retain guards after logout. Other tests
verify no research example enters patient history, exact fixture values, retry,
mobile navigation, accessibility labels and 320px/large-text layout. The full
existing assessment, repository, security and explanation suites still pass.

`flutter build web --no-pub` succeeds. It emits a CupertinoIcons font warning;
this update adds no Cupertino icon usage or dependency changes. Model artifact,
processed dataset and saved-prediction hashes match the audited manifest.

Screenshots were rendered and visually reviewed at 390px, 820px and 1440px:

- `build/research_review/research_390px.png`
- `build/research_review/research_820px.png`
- `build/research_review/research_1440px.png`

Re-render with:

```powershell
flutter test --no-pub test/research_demo_test.dart --dart-define=RESEARCH_SCREENSHOTS=build/research_review
```

These are Flutter widget renders, using the test helper's SDK font substitutions,
not Chrome screenshots. **Live Chrome UI testing was unavailable**: the browser
inventory was empty. Real browser refresh and history should still be checked
manually with the direct public URL above. No browser session persistence was
added. No model, dataset or artifact was modified, and nothing was retrained,
committed, pushed, merged or deployed. Unrelated working-tree changes were preserved.
