# Synthetic patient workflow audit

This is a supervised research demonstration, not clinical validation. Use synthetic
inputs only. Model artifacts, research datasets, UCI prediction logic and SHAP
calculations are unchanged.

## Findings and changes

- **New Assessment:** `/assessment` was classified as a temporary-only route,
  so a full reload deliberately returned to Dashboard. It now rebuilds a blank,
  unassociated form behind the existing demo guard. The notice says any previous
  unsaved draft and patient selection were not restored. The wording does not
  assert that a draft existed: no draft-presence flag or draft data is stored.
- **Patients list:** `/patients` was already restorable. There was no confirmed
  list-routing defect. Back/Forward in a live app retains repository records;
  full reload creates only the existing synthetic seed repository. Search/filter
  UI state is temporary. Disappearing entered records are not recreated.
- **Patient Details and History:** history is embedded in the detail screen.
  The generic `/patient-details` URL contains no selected patient ID. On reload
  or browser-history delivery it now returns to Patients with an explanation,
  rather than Dashboard. Even if a seed record still exists, it must be selected
  again; the URL cannot identify which record was open. A record removed while
  the detail widget is alive now shows **Record unavailable** and a working
  **Return to Patients** action, replacing the bare “Patient not found” dead end.
- **Processing, Risk Result and SHAP:** refresh still returns to Dashboard with
  a lost-state explanation. No inference or result is silently recreated. In-app
  Back uses the live form/result/record stack. Browser history into an assessment
  URL opens a blank form and reports the reset.
- **Creation and saving:** a form proposes a new session ID, but no patient is
  created until Save. Save inserts the actual assessment object into the
  in-memory repository and opens its details/history. Discard inserts nothing.

The URL flow is `/assessment` → `/processing` → `/result` → Save →
`/patient-details`; opening a history item gives `/result`, then SHAP gives
`/explanation`. No URL includes identifiers, measurements or result data. The
DEMO-ONLY marker remains the only browser-storage entry. Logout clears it and
entered records; protected destinations remain gated.

## Functional verification

The live local UCI HTTP service was queried with authored synthetic measurements.
The three cases below returned Low, Moderate and High predictions. Their exact
probabilities and SHAP were captured in
`test/fixtures/uci_workflow_responses.json`, with the saved model SHA-256. These
are software regression fixtures, not clinical examples or new research data.

| Synthetic case | Age | BP (mmHg) | Glucose (mmol/L) | Temperature (°F) | HR | Model prediction |
|---|---:|---|---:|---:|---:|---|
| A | 25 | 110/70 | 5.5 | 98.4 | 75 | Low |
| B | 29 | 130/90 | 7.5 | 98.4 | 85 | Moderate |
| C | 40 | 160/110 | 12 | 101 | 100 | High |

Flutter workflow tests replay those actual responses through the existing
ApiRiskClassifier using mocked HTTP transport. They enter all six fields, check
the outgoing canonical-unit payload, result category, all probabilities and SHAP
values, save, reopen the saved history item, open SHAP, return, and logout. They
also exercise HTTP 503 → Retry and HTTP 503 → Edit values → resubmit, preserving
the draft in memory; discard then opens blank without saving. No simulated
classifier is substituted on failure.

Backend tests independently reproduce all three response fixtures from the saved
model, including the API's SHAP reconstruction checks. Existing research tests
check R1–R6 and all 92 locked UCI predictions. Passing software tests does not
establish clinical validity. These widget/router tests are not live Chrome tests.

Verification completed for this change: `flutter analyze --no-pub` found no issues;
the full Flutter suite passed 152 tests with 4 opt-in tests skipped. The additional
browser-provider URL assertion passed its targeted rerun. Sixteen backend tests
passed (workflow fixtures, research/UCI regression checks and API privacy tests).
The API-enabled Flutter web build succeeded, with an existing missing Cupertino
font warning. Live HTTP requests covered all three risk categories; live Chrome
and Android verification of the updated UI remains manual.

## Confirmed limitations remaining

- No durable patient database, real authentication or patient-specific deep links.
- A lost draft, selected patient or entered record cannot be restored without
  retaining that state elsewhere. None is retained by this change.
- Generated IDs are session-local and may be reused after reset; they are not
  stable patient identities. A repeated ID does not mean an old record survived.
- Export/printing intentionally shows an unavailable message. It is not connected
  to an export service. Seeded histories/explanations remain simulated even when
  new assessments use the UCI API.
- The updated workflow has not been exercised live in Chrome or Android during
  this change. Live UCI HTTP checks and mocked-transport widget tests are distinct.

## Exact manual Chrome checklist

### Follow-up investigation — 2026-10-26

The presenter reported that blank Assessment, Patients, How AIOVY Works, research
R4 refresh, and logout followed by browser Back passed in Chrome. A Patient
Details refresh reportedly returned to Home; its before/after URL and notice were
not recorded. This discrepancy remains unresolved: current-source tests opening
a patient through the real Home and Patients controls publish `/patient-details`,
then a fresh router/repository with only the demo marker falls back to `/patients`
and displays the selection-unavailable notice. This is automated restoration
coverage, not a reproduction or resolution of the Chrome observation. No runtime
routing change is justified by those passing tests alone.

The presenter clarified that the reported Result/SHAP return to Home followed a
browser refresh. That matches the intentional lost-state fallback; a separate
in-session Save failure has not been confirmed. Strengthened tests now use the
actual Home assessment and explanation controls for all three risk categories,
return with the app Back arrow before saving, and verify the same assessment
object, one saved history entry, saved-result/SHAP navigation, and logout. There
is no replacement classification while navigating that flow. Widget tests replay
the captured API fixtures; backend tests independently verify the real artifacts.

Follow-up verification: analysis found no issues; the full Flutter suite passed
154 tests with 4 opt-in tests skipped, and all 16 backend regression/privacy
tests passed. No live browser or Android testing was performed for this follow-up.

Before declaring the Patient Details report resolved, restart the current web
build and record the exact URL immediately before/after refresh and the full
notice. `/patient-details` should return to `/patients`; a history entry opens a
saved `/result`, whose refresh intentionally returns to Dashboard. Exact
restoration of entered Result/SHAP data after refresh is unavailable without
retaining that state elsewhere; no persistence or synthetic replay is added.

### Retest steps

1. Restart/rebuild Flutter with `USE_API=true`, UCI port 8000 and research port
   8001 as in the root README. Existing running Flutter builds may still contain
   old routing code. Begin a DEMO-ONLY session; confirm no real patient data is used.
2. From Home choose New assessment. Confirm `/#/assessment`, six blank inputs,
   and no new saved patient. Enter part of case A, then refresh. Expect the same
   route with a blank **new** form, reset notice and no copied patient values.
3. Complete case A, then separately B and C in fresh assessments, keeping Settings
   at mmol/L and °F. Expect Low, Moderate and High respectively. Compare exact
   outputs with the fixture JSON; UI percentages may be rounded. Check the URL
   changes through `/processing` and `/result`.
4. Save each result. Expect `/patient-details` and one corresponding history
   entry. Open the entry, verify Saved result has no Save action, open SHAP, and
   use in-app Back to return through the same live result and patient record.
5. Open the Patients tab: expect `/patients` and the newly saved synthetic
   record. Use browser Back/Forward through safe pages without reloading: the
   in-memory record should remain. Refresh `/patients`: seed records remain;
   session-entered records must disappear, with no replacement inference request.
6. Open a seed patient's Details, then refresh `/patient-details`. Expect
   `/patients` plus the selection-unavailable notice; select the seed again to
   view its history. No arbitrary seed should be selected automatically.
7. From Details choose New assessment; confirm the “Copied from the last visit”
   warning and `/assessment`. Refresh: expect blank **new** assessment, not a
   form still associated with the previous patient. Browser history to the form
   has the same blank/reset behavior. Existing seed history must not change.
8. Classify without saving, choose Discard and assess another patient, then
   confirm Discard & Start New. Expect a blank form and no added history entry.
   Also check Cancel/Keep Reviewing and the unsaved-form discard confirmation.
9. In a controlled local run, stop your own UCI server and submit synthetic
   inputs. Expect an error, no result and no saved record. Edit values must retain
   the draft. Restart the server and Retry; verify a new request succeeds. Do not
   interpret this manual exercise as performed by the automated tests.
10. Logout using Profile and separately the demo banner. Inspect sessionStorage:
    the marker must be gone. Refresh and Back/Forward to `/assessment`, `/patients`
    and `/patient-details` must show the demo gate, not prior records. Public
    Research Demonstration R1–R6 remains accessible and cannot save to history.

## Files for this change

```text
lib/navigation/web_router.dart
lib/screens/assessment/assessment_input_screen.dart
lib/screens/patient_profile/patient_profile_screen.dart
test/patient_workflow_test.dart
test/fixtures/uci_workflow_responses.json
test/demo_session_test.dart
test/web_router_test.dart
ml_model/uci/api/test_workflow_fixtures.py
README.md
docs/demo-browser-session.md
docs/web-routing-audit.md
docs/patient-workflow-audit.md
```
