# Visible-page URL audit — 2026-10-24

## Confirmed bugs versus intended fallbacks

Before the fix, live Chrome at `127.0.0.1:8080` showed **How AIOVY Works** while
the address bar remained `/#/profile`. Refresh returned to Profile. Clicking the
Profile bottom tab did correctly publish `/#/profile` and display Profile.

The informational screen was an unnamed imperative route. The observer recognized
only temporary assessment routes, so this safe page inherited its parent's URL.
Code inspection established the same issue when opened from SHAP: the URL stayed
`/#/explanation`, whose refresh intentionally discards lost assessment state.
That explains an informational page incorrectly ending up on Dashboard with a
lost-state message. Onboarding and Login pushes also lacked independent names.

Dashboard, Patients and Profile share an IndexedStack, not separate nested
Navigators. Their tab notifier updates the web router. Settings and public research
already used declarative router navigation. The outer Navigator also holds
imperative assessment, patient-detail and explanation pages. Browser history
contains only allowlisted paths, not route widget arguments or patient objects.

## Implemented safe-route correction

`RestorableWebPage` separates data-independent named pages from
`TemporaryWebPage`. AppNavigator assigns their generic route names, and the
observer reports the actual top named imperative page. Declarative root-page
names are not allowed to overwrite the selected tab URL. Direct URL/history
delivery rebuilds informational pages without reconstructing an assessment.

| Visible screen | Hash URL | Full-refresh behavior |
|---|---|---|
| Dashboard | `/#/dashboard` | Restore with demo marker |
| Patients list | `/#/patients` | Restore list with synthetic seeds; entered records are lost |
| Profile | `/#/profile` | Restore with demo marker |
| Settings | `/#/settings` | Restore screen; preferences remain in memory and reset |
| How AIOVY Works | `/#/how-aiovy-works` | Restore with demo marker, regardless of its previous parent |
| Research Demonstration | `/#/research-demonstration/R1` … `/R6` | Public; restore selected fixed example |
| Intro / Login / Onboarding | `/#/`, `/#/login`, `/#/onboarding` | Public; onboarding starts at first slide |
| New Assessment | `/#/assessment` | Blank new form + reset notice; no previous patient association |
| Processing | `/#/processing` | Dashboard + lost-state explanation, or demo sign-in gate |
| Risk Result / SHAP | `/#/result`, `/#/explanation` | Same intentional fallback; no replacement inference |
| Patient details/history | `/#/patient-details` | Patients list + selection-unavailable notice; no patient ID in URL |

The existing DEMO-ONLY marker is unchanged. Logout clears it and entered records;
protected history destinations remain gated. Named informational navigation uses
the existing mobile push/pop behavior. In-app Back from information opened over
SHAP returns to the same live explanation. Browser Back/Forward into a temporary
URL still intentionally falls back, even when an earlier object might have been
in memory. Stale lost-state notices are removed when navigating to a different
safe page so they do not misleadingly describe the new destination.

## State-dependent restoration: proposal only

A full refresh destroys the Dart heap. The demo-mode marker contains no identity
or assessment data; generic route names cannot reconstruct entered measurements,
selected patient, prediction, SHAP, or history. Exact restoration of arbitrary
assessments needs data retained somewhere, such as storage or a server session,
which is outside the current privacy constraints. Browser Back/Forward cache is
not a reliable substitute for full refresh. The later patient-workflow fix now
rebuilds an empty new form, as shown in the table above; it does not restore
previous inputs or patient association.

A possible **synthetic-demo-only** alternative is a separately labelled, fixed
walkthrough with public step IDs referencing bundled synthetic fixtures. A step
could rebuild synthetic inputs and request a new UCI prediction, explicitly
labelled as regenerated from a fixed preset, without storing patient payloads.
It must never silently recreate a user's assessment, serve invented fallback
outputs, accept arbitrary patient input for restoration, or save to patient
history. Fixture sources, labels, API behavior and logout handling would need
separate review. **This alternative is not implemented and requires approval.**

## Verification scope

Regression tests exercise real tab clicks and informational entry points, route
information reporting, fresh-router restoration with only a demo marker,
Back/Forward route delivery, logout guards, public research R1–R6 selection, and
information opened over SHAP. Simulated route-information delivery is not a live
Chrome history test. Live browser observations and final test results are reported
separately in the implementation response.

Verification of the earlier informational-route correction (before the later
patient-workflow tests): `flutter analyze --no-pub` found no issues;
`flutter test --no-pub` passed 143 tests with four opt-in tests skipped. The local
web build succeeded, including its Wasm dry run, with the existing missing
Cupertino font warning. Model/data/artifact and pre-existing lock/cache hashes
were unchanged.

Live Chrome: the old informational URL mismatch and parent-page restoration were
reproduced. In an isolated updated build on loopback port 8081, direct access to
How AIOVY Works first showed the demo gate; simulated sign-in opened the page,
and a full refresh retained that page and its own URL. Profile tab URL publishing
was observed on the original build. A complete post-fix Chrome Back/Forward,
logout, other-safe-page refresh and all-six-example walkthrough remains a manual
check; automated coverage is not claimed as live browser verification. No Android
testing was performed. No state-dependent restoration alternative was implemented.

Files changed for this routing correction (earlier uncommitted work is retained):

```text
README.md
docs/demo-browser-session.md
docs/web-routing-audit.md
lib/navigation/app_navigator.dart
lib/navigation/route_session.dart
lib/navigation/web_router.dart
lib/screens/login/login_screen.dart
lib/screens/research/research_screen.dart
lib/screens/welcome/onboarding_screen.dart
test/demo_session_test.dart
```
