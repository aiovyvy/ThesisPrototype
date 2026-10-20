# AIOVY UI/UX Redesign: Report

Branch `feature/ui-redesign` (local only; not pushed or merged). Base: `origin/feature/uci-integration` @ `da45c6d`.
The plan is in [`ui-redesign-plan.md`](ui-redesign-plan.md).

## 1. Summary

The existing Flutter app was redesigned in place: same architecture, same `RiskClassifier` seam, same FastAPI
contract, same repository and validation rules. Nothing was mocked or replaced. Along the way, two functional bugs in
the UI layer were found and fixed. Both affected the trained-model (API) path:

1. **The SHAP wording contradicted the API.** The API returns SHAP values *for the predicted class*, but every
   positive bar was labeled "Raises risk". For a Low Risk result from the trained model, the values that *supported*
   Low were shown as raising risk. All explanation wording now goes through `ContributionFraming`
   (`lib/widgets/explanation_widgets.dart`):
   - trained-model results → "Supports / Against \<predicted level>" (as `ml_model/uci/api/README.md` §4 already
     expected);
   - demo results (`isDemo`) → "Toward higher / lower risk", which is what the mock heuristic's numbers mean.
2. **An unreachable API froze the app on the processing screen.** `RiskClassifierException` was never caught. The
   screen now shows the classifier's message with **Try again** and **Edit values**, and nothing is saved.

## 2. Screens redesigned

| Priority | Screen | Main changes |
|---|---|---|
| 1 | Assessment form | Grouped into *Mother / Blood pressure / Other vital signs*. Systolic and diastolic side by side ("top number / bottom number"). 56 dp numeric fields with the unit always visible. The expected range is always shown and replaced by a plain error. "Heart rate: mother's pulse, not fetal heart rate". 6-segment progress bar with a sticky **Assess risk**. A visible warning when values are copied from the last visit. |
| 1 | Processing | Calm progress view; error state with retry (bug 2); "demo classifier" note only in demo mode; static spinner when the OS asks for reduced motion. |
| 2 | Result | Risk-tinted verdict with the model's probability for that level. High-risk alert directly below. Three labeled probability bars. **Main factors**: top 3 contributions inline with correct wording, plus "See all 6 indicators". Entered-values grid. Sticky **Save to patient record**. Assessor shown on saved results. |
| 2 | Explanation (SHAP) | Diverging bar chart (against ← \| → supports) with entered value and signed SHAP value per row. One-line summary. The method note explains probability units for model output. |
| 3 | Home | Greeting and date, solid **New assessment**, *Needs review* (patients whose latest saved result is High, read from the repository), today's counts by level, recent assessments as dense rows. |
| 4 | Patients / profile / history | Grouped dense rows; values never split across lines; 48 dp filter chips. Profile: status card, **New assessment**, latest-values grid, history with "↑ Up from Low" change markers. |
| 5 | Login | Same fields, validators, autofill, toggle and sign-in flow. Removed the unsupported "Secure Session" and "12-hour session" claims; added an honest prototype note ("use demo records only"). |
| 6 | Splash / welcome | Three factual capability lines (replacing "Real-Time / Explainable / Protected"), "Decision support only", **Get started**. |

Profile, Settings and How AIOVY Works were not restructured; they pick up the new tokens and components.

### Design system

- **Color** (`app_colors.dart`). Warm neutral canvas, white surfaces with hairline borders instead of shadows. Rose
  is reserved for actions, focus and selection. **High risk is now `#B42318`** (a true red) so it no longer looks
  like the rose primary color. Every ratio in the file comments was computed: text ≥ 4.5:1, input borders ≥ 3:1.
- **Type** (`app_text_styles.dart`). Real Inter weights are now loaded. Before, only the regular file loaded and all
  bold text was synthesized by the engine. Body text is 16 px; numbers use tabular figures; 12 px is the minimum.
- **Components.** `StickyActionBar`, `GroupedList`, `PatientListRow`, `AssessmentListRow`, `IndicatorGrid`,
  `RiskChangeMarker`, `ProbabilityBars`, `ContributionBar`, `ContributionLegend`.

## 3. Files changed

UI (`lib/`): `core/theme/{app_colors,app_spacing,app_text_styles,app_theme}.dart`;
`screens/{assessment/assessment_input_screen,assessment/indicator_input_card,home/home_screen,login/login_screen,patient_profile/patient_profile_screen,patients/patients_screen,processing/processing_screen,result/result_screen,shap/shap_screen,splash/splash_screen}.dart`;
`widgets/{app_header,bottom_nav,buttons,common,patient_widgets}.dart`; **new** `widgets/explanation_widgets.dart`.

Tests: **new** `test/helpers/test_app.dart`, `test/redesign_test.dart`, `test/screenshots_test.dart`;
`test/widget_test.dart` (button label "Get Started" → "Get started").

Other: `analysis_options.yaml` (`formatter: page_width: 120`, matching the existing code), `docs/`.

**Not changed** (verified with `git diff da45c6d`): `lib/services`, `lib/models`, `lib/data`, `lib/state`,
`lib/main.dart`, `lib/app.dart`, `ml_model/**`, `pubspec.yaml`, `android/`, `web/`. No dependencies were added.
`pubspec.lock` shows local changes because the IDE re-resolved SDK-pinned packages for Flutter 3.41.9. It is **not
committed**; restore it with `git checkout pubspec.lock` if you prefer.

## 4. Tests executed

Flutter 3.41.9 / Dart 3.11.5, Windows.

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **43 passed**, 1 skipped (screenshot harness, opt-in) |
| `dart format` (edited files) | Clean |

The new tests cover:
- SHAP wording for a model Low result, the documented API High example, and demo output;
- empty submit (all six highlighted, no navigation) and the diastolic ≥ systolic check;
- the full flow: enter six values → processing → result (no demo tag, "Supports High Risk") → save → the record
  exists → profile opens;
- classifier failure → message, Try again → result (2 calls); no "demo classifier" text in API mode;
- glucose unit kept intact in history text;
- 30 layout checks: 10 screens at 320×568 with text ×1.3, and at 360×640 with text ×1.0 and ×1.5. No overflow.

The API-mode fixture is the `/classify` example documented in `ml_model/uci/api/README.md`. No SHAP values were
invented for anything the app displays. The one other test-only result (a Low prediction used to check wording) is
labeled as a fixture in the test file.

**Screenshots.** Run `flutter test test/screenshots_test.dart --dart-define=SCREENSHOTS=<folder>`. It writes 17 PNGs.
They use the SDK's Roboto in place of Inter.

## 5. Remaining issues and limitations

- **Release builds.** `android/app/src/main/AndroidManifest.xml` has no `INTERNET` permission (this predates the
  redesign). A release APK can't download Inter, so text falls back to Roboto, and it can't call the API. Also,
  google_fonts downloads Inter at runtime. For offline field use, consider bundling the Inter `.ttf` files as assets;
  google_fonts picks them up automatically. Neither change was made, because both touch platform config or assets.
- **The demo cohort is always mock-scored.** `MockPatients` runs through `MockRiskClassifier` even in API mode, so
  seeded records and their explanations stay "Demo output". This is existing data flow and was not changed.
- **Processing steps are paced, not real progress.** The three steps advance on timers while one classifier call
  runs. This is the existing behavior.
- **Label wording.** The wording uses "supports / against" and does not state causality. It has not been reviewed
  by clinicians.
- **Secondary screens.** Settings and How AIOVY Works were not redesigned beyond tokens.
- **Language.** There is no Filipino localization. The copy is plain English for non-technical users.

## 6. Manual verification for tomorrow

1. **Demo mode** (`flutter run`) on a small Android phone or emulator (~360 dp):
   - Splash → Login → Home.
   - New assessment: tap **Assess risk** empty and check the highlighting and focus. Enter systolic 90 / diastolic 95
     and check the cross-check error.
   - Use sample values → Assess risk → result → **See all 6 indicators** → back → Save → profile shows the new entry.
   - Settings → switch to mg/dL and °C, then reopen an assessment and check the values convert.
2. **API mode** (`--dart-define=USE_API=true`, server running): run the README §4 cases T1–T9.
   - Check the probabilities and the legend wording. **T1/T2 (Low)** are the key check for the fixed wording: they
     should read "Supports Low Risk".
   - Stop the server and assess again: you should see the error with Try again / Edit values, and your values kept.
3. **TalkBack:** confirm that the verdict, probability bars, contribution rows and form fields read sensibly.
4. **Large text:** set system font size to the largest and skim the main screens.
5. **Decide:** add `INTERNET` to the main manifest and/or bundle Inter fonts for release (section 5)?

---

# Refinement pass ("modern clinical warmth")

A selective second pass on the same branch. Layouts, screen structure and both bug fixes (SHAP wording relative to
the predicted level; API error state) are unchanged. Before/after screenshots were rendered at 360 dp and at
1280 px (desktop web) with the opt-in harness.

## What looked generic, and the change

| Before | After |
|---|---|
| Saturated magenta primary (`#A32F5E`) | Muted rose `#A65B76` (white text 4.8:1); `#82445F` for rose text on tints (6.2:1) |
| Cool off-white canvas, near-black text | Warm ivory `#FAF8F6`, warm charcoal `#302B30` (13.1:1) |
| "Valid input" shown in the Low-risk green | Sage `#789486` marks completed fields, so input state never looks like a risk level |
| Pink icon tiles on splash, settings, profile | Plain icons; tiles removed or neutral |
| Gradient avatar with a green "On shift" dot (no shift tracking exists) | Plain initials |
| Risk shown twice per row (tinted number tile + badge, or icon + badge) | Badge only; rows are shorter |
| Content stretched edge to edge on desktop (1,250 px button) | 640 px content column for pages, headers and action bars; 520 px tab bar |

All new colors were contrast-checked by script (WCAG 2.1); ratios are in `app_colors.dart`.

## Clutter removed

- **Assessment:** "Enter all six values" (the progress bar says it), the footer disclaimer (the notice appears at the
  result, where the decision is made), the decorative patient icon, and **the range line under every field**. The
  range is now the empty field's placeholder (e.g. "12–65"); the full range text appears only in errors and in the
  screen-reader label.
- **Result:** the boxed verdict icon, the generic sentence ("Several indicators are associated with…"), the separate
  probability card (merged into the verdict), the separate high-risk alert box (now inside the verdict, same text),
  and the tinted notice box (now a quiet caption naming the model).
- **Explanation:** "Little effect on this result" is no longer repeated on every negligible row.
- **Home:** the "Today" card became one line of counts under the date; the translucent circle on the main action is
  gone; the "no high-risk patients" note is no longer green.
- **Profile:** "Latest values" merged into the status card; history rows drop their icon column.

## Usability

- Wording now presents output as an estimate: "Model estimate" (result), "Latest model estimate" (profile, was
  "Current status"), "Latest model estimate is High Risk" (Home), "Estimated by \<model>" beside Save.
- With the keyboard open, the assessment bar keeps only **Assess risk**. Scaffold hides the keyboard inset from its
  body, so the state is read above the Scaffold.
- Shorter rows and merged cards reduce scrolling on Home, Result and Profile.
- Vitals stay on one line ("HR 82", "BP 142/92", "5.6 mmol/L"); lines break only between values.

## Screens changed

Assessment, Processing (layout width only), Result, Explanation, Home, Patients, Patient profile, Clinician profile,
Splash, and shared header, tab bar, rows and settings tiles. Login changed only through tokens.

## Tests

`flutter analyze`: no issues. `flutter test`: **50 passed**, 1 skipped (screenshot harness). Added tests:
- estimate labelling;
- the high-risk alert follows Settings;
- range text appears only in errors;
- the keyboard-open bar;
- content ≤ 640 px at 1280 px width (assessment, result, patients).

All earlier tests still pass, including the SHAP wording and API error tests and the 30 small-screen and large-text
overflow checks.

Found and fixed during the pass:
- the new width helper initially used a plain `Center`, which made the sticky action bar fill the screen (caught by
  the flow tests);
- the first keyboard check read the inset below the Scaffold, where it is always zero (caught by the new test).

## Limitations

- Not done: a separate "review values" step (as in the reference mockup); it would add a tap to every assessment.
- Rendered screenshots use Roboto in place of Inter.
- The earlier items in §5 (release `INTERNET` permission, mock-scored demo cohort) still apply.
