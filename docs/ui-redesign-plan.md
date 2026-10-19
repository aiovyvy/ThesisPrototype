# AIOVY UI/UX Redesign Plan

Branch: `feature/ui-redesign` (local only, created from `origin/feature/uci-integration` @ `da45c6d`).

## 1. Scope and constraints

The redesign is **frontend only**. These files and folders are treated as read-only:

- `lib/services/**` (the `RiskClassifier` interface, `ApiRiskClassifier`, `MockRiskClassifier`)
- `lib/models/**`, `lib/data/**`, `lib/state/**` (data flow, repository, settings)
- `ml_model/**` (models, datasets, notebooks, FastAPI server, reports)
- `pubspec.yaml` dependencies (no new packages)

The redesign does not change authentication behavior (the prototype accepts any non-empty credentials), the API request or response contract, validation ranges, or how assessments are saved.

## 2. Audit summary

### Architecture (kept as is)

- `main.dart` picks `MockRiskClassifier` (default) or `ApiRiskClassifier` (`--dart-define=USE_API=true`).
- Screens read services through `AppScope` (InheritedWidget) and rebuild through `AppStateBuilder`.
- `RiskResult` = `riskLevel`, `probabilities`, `modelName`, `featureContributions`, `isDemo`.
- The seeded demo cohort (`MockPatients`) is always scored by the mock classifier, even in API mode, so those records keep `isDemo = true`.

### Bugs found in the existing UI (fixed in this redesign)

| # | Severity | Problem | Fix |
|---|---|---|---|
| B1 | **High (clinical communication)** | The SHAP screen labels every positive bar "Raises risk" and every negative bar "Lowers risk". The API returns SHAP values **for the predicted class**, so a Low-risk API result showed the values supporting "Low" as "raises risk", which is the opposite of their meaning. `ml_model/uci/api/README.md` §4 already expects "Supports <level>" / "Against <level>". | Add `ContributionFraming`: trained-model results use "Supports / Against <predicted level>". Demo results keep the mock heuristic's meaning ("Toward higher / lower risk"). The values themselves are unchanged. |
| B2 | **High** | `ProcessingScreen` never catches `RiskClassifierException`. If the API is unreachable, the spinner runs forever. The API README describes **Try Again** / **Edit Indicators** buttons that did not exist. | Add an error state that shows the classifier's message, with Try again (re-runs the same indicators) and Edit values (returns to the form, values kept). |
| B3 | Medium | The processing screen always says "Demo classifier – not a trained model", even in API mode. | Show this only when `classifier.isDemo`. |
| B4 | Medium (typography) | The theme sets `fontFamily: 'Inter_regular'`, so only the regular Inter file is loaded and every semibold or bold label is synthesized ("faux bold"). | Build text styles through `GoogleFonts.inter(...)` per weight, which loads the real Medium, SemiBold and Bold files. |
| B5 | Low (honesty) | Copy that claims things the prototype does not do: "Secure Session", "Protected", "Real-Time", "Keep 12-hour active bedside session". | Replace with accurate copy. The toggle and its setting are unchanged. |

### UX problems

- **Assessment form:** six identical floating cards with no grouping. Systolic and diastolic are separate cards, although clinicians record and read BP as one value (120/80). Pink icon tiles everywhere weaken hierarchy.
- **Result:** the verdict is good, but the probability bar is 8 px thick with a small legend, and an OB-GYN must open a second screen to see *why*. The inputs are a long list.
- **Home:** a large gradient hero with a decorative "BEDSIDE TRIAGE" pill and glow shadow looks generic. High-risk patients who need review are not surfaced.
- **Patients / history:** heavy shadowed cards, so there is little information per screen. History does not show whether risk went up or down between visits.
- **System-wide:** soft shadows on every card, rose tints used decoratively, 20 px margins, body text at 15 px.

## 3. Design direction: "clinical calm"

The approach: quiet surfaces, clear structure, and color reserved for meaning.

- **Color.** Warm neutral canvas (`#F6F4F3`), white surfaces with a 1 px hairline border instead of shadows. Rose `#A32F5E` is used only for primary actions, focus, selection and links. Risk colors are semantic only, always paired with an icon and text. **High risk moves from `#C2364B` to `#B42318`** (a truer red, 6.6:1 on white) so it no longer looks like the rose brand color and primary buttons don't read as "danger".
- **Typography.** Inter with real weights. Body text is 16 px (up from 15) for legibility in the field. Numbers (vitals, probabilities, SHAP values) use tabular figures. The minimum size stays 12 px.
- **Spacing.** 4 pt grid, 16 px page margin (more room on 360 dp phones), 48 dp minimum touch targets, 56 dp numeric inputs.
- **Shape.** Radius 12 (controls) and 16 (cards). No glow shadows. Elevation only on sticky action bars.
- **One primary action per screen**, always as a filled rose button, usually in a sticky bottom bar.

## 4. Screen plan (priority order)

1. **Assessment form.** Three labeled groups: *Mother* (age), *Blood pressure* (systolic / diastolic side by side, "top number / bottom number" hints), *Other vital signs* (glucose, temperature, heart rate). Large numeric fields with the unit inside. The expected range is always visible and replaced by a plain-language error when needed. A sticky bar shows a 6-segment progress meter and **Assess risk**. For existing patients, a visible notice says the values are copied from the last visit and must be re-measured. Validation rules and ranges are unchanged.
2. **Processing.** A calm progress state, the real error state (B2), and accurate demo labeling (B3).
3. **Result.** A verdict block (risk level, icon, model probability for that class, patient, time, saved state). Probabilities as three labeled bars. **Main factors**: the top 3 contributions inline, with correct framing (B1). A link to the full explanation. A compact 2-column input grid. The existing high-risk alert text and decision notice. Sticky **Save assessment**.
4. **Explanation (SHAP).** A diverging bar chart (against ← | → supports), one row per indicator, sorted by impact, with the entered value and signed SHAP value. A plain-language summary uses the same framing. The method and model notes stay in a collapsible card.
5. **Home.** Compact greeting and date, a solid **Start new assessment** action, a *Needs review* list (patients whose latest result is High, derived from the repository), today's counts by risk, and recent assessments as dense rows.
6. **Patients and patient profile.** Grouped dense rows, search and risk filters. Profile: status header, **New assessment**, latest values grid, and a history timeline with a risk-change marker (e.g. "↑ from Moderate").
7. **Login.** Wordmark, two fields, **Sign in**, and an honest prototype note. The behavior is unchanged.
8. **Splash / welcome.** Brand mark, one-line purpose, three factual capability statements, "Decision support only" line, **Get started**.

Secondary screens (Profile, Settings, How AIOVY Works) pick up the new tokens and shared components without structural changes.

## 5. Verification plan

- `dart format` (page width 120, matching the existing code) on edited files only, so files outside the UI stay byte-identical.
- `flutter analyze` with zero issues, and `flutter test` with all existing and new tests passing.
- New tests: SHAP framing; the assessment form (validation, BP cross-check, full submit → result → save flow); the processing error state with retry; overflow smoke tests for the key screens at 320×568 and 360×640 with 1.3× text scale.
- A rendered-screenshot harness (opt-in, `--dart-define=SCREENSHOTS=true`) for visual review.
- `git diff --stat` check that `lib/services`, `lib/models`, `lib/data`, `lib/state` and `ml_model` are unchanged.
