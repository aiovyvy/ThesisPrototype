# Temporary DEMO-ONLY browser access

This convenience feature is for a supervised Thesis 1 presentation with synthetic
assessment inputs and fixed public research examples. **It is not authentication,
clinical approval, or protection for real patient data.** No backend access
control is added or changed.

## Exact persistence contract

After the existing simulated sign-in, Flutter web writes one fixed, non-secret
entry to this origin's tab-scoped `window.sessionStorage`:

```text
aiovy.demo-only-mode = enabled-v1
```

There is no random identifier, identity, credential, token, assessment payload or
route in that entry. It means only that this browser tab opted into demo UI mode.
Anyone can set it manually. It is never sent in API requests. A visible banner
continually labels access **DEMO-ONLY** and **not authentication**; the sign-in
screen explains the marker before starting it.

The app does not write credentials, patient identifiers, measurements,
predictions, SHAP contributions or history to localStorage, sessionStorage,
cookies, browser-history payloads or URLs. Credential autofill hints are disabled
on web; browser extensions/password managers remain outside AIOVY's control.
Patient and assessment objects remain in Dart memory only.

Normal refresh preserves the marker in the same tab. Session storage normally
ends with the tab's browsing session, but browser session restore may preserve it
and duplicated/opener tabs can receive an independent copy. There is no timeout
or cross-tab session revocation. **Use Logout and close other demonstration tabs;
do not rely on browser close as a security boundary.** Changing origin/port means
a different marker. No localStorage or cookie fallback is used.

If session storage is blocked, sign-in remains memory-only and an on-screen
message explains that refresh cannot restore access. Unrecognized marker values
do not grant demo access. Logout invalidates then removes the entry and verifies
removal, clears entered records, resets the tab selection and disposes the old
protected navigation stack. If browser storage becomes inaccessible during
logout, current in-memory access still ends and a warning instructs the presenter
to close the tab and clear this site's session storage. Removal cannot be
guaranteed when the browser refuses storage operations; do not continue a shared
workstation demonstration until that warning is resolved.

On browser `pageshow` and focus events, the router rechecks the marker. A cached
document whose old Dart heap still says demo mode was enabled is signed out and
cleared if the marker has been removed. Browser-level behavior still needs the
manual checks below; this does not create a security boundary.

## Refresh and browser navigation

- `/dashboard`, `/settings`, `/profile`, `/patients`, `/how-aiovy-works`: resume demo UI access when
  the marker exists. Refresh constructs a new repository with synthetic seed
  records, not previous session-entered records. A notice explicitly says records
  and assessments were not restored.
- `/`, `/login`, `/onboarding`: public, non-patient screens. Onboarding reloads
  its first slide. Named informational pages now publish their own URLs even
  when pushed over a live explanation; in-app Back still returns to that live
  screen. See the [routing audit](web-routing-audit.md).
- `/assessment`: restores a blank **new** form, not a patient-associated draft.
  A concise notice says any previous draft and patient selection were not
  restored. No patient is created and no classification occurs until explicitly
  requested; a new patient record is created only on Save.
- `/patient-details`: returns to `/patients` with a selection-unavailable notice.
  History is part of the detail screen, not a separately restorable record. A
  record still in memory or among the seeds can be selected again. An entered
  record lost on refresh is not recreated.
- `/processing`, `/result`, `/explanation`:
  these generic names contain no identifiers or measurements. Refresh or browser
  Back/Forward to them returns to Dashboard with a lost-state notice (or the demo
  sign-in gate if logged out). No stored result is reconstructed and no inference
  is triggered to recreate one. Browser history deliberately does not resurrect
  transient result pages, even if a previous object may still have been in memory.
- In-app Back from SHAP still returns to its live result. Normal assessment,
  result save/discard and history behavior remain in memory. Late navigation from
  an asynchronous assessment cannot open a protected result after logout.
- `/research-demonstration/R1` through `/R6`: remain public and independent of the
  marker and patient repository. Refresh and Back/Forward restore the fixed
  selected example. Nothing can be entered or saved as a patient record.
- After Logout, protected history destinations require a new simulated sign-in.
  This is a demo convenience guard, not production authorization.

Mobile does not construct the web router or use this storage adapter. Its
navigation remains in memory. Generic route settings do not contain patient
objects or identifiers. Backend models, inputs, probabilities and SHAP are
unaffected.

## Result footer

The result list has an explicit viewport above a separately measured sticky Save
footer. Save wraps at larger text sizes instead of truncating. Discard is a
wrapping action in the scrollable content, keeping the footer compact. The final
disclaimer remains scrollable above it. Saved results have no Save footer.

## Automated versus manual verification

`test/demo_session_test.dart` uses an injected tab-storage adapter to simulate
refresh without persisting a repository. It checks fixed marker contents,
credential/data exclusion, restored safe routes, generic live result/SHAP URLs,
lost-state fallback, blocked storage, logout/history guards and footer geometry.
Existing web-router/research/assessment/security suites remain relevant. Widget
and simulated-history tests do not establish actual browser sessionStorage or
Chrome history behavior. A web build checks browser-adapter compilation.

Before presenting, check in real Chrome with a freshly restarted Flutter build:

1. Sign in, inspect DevTools Application → Session Storage: only the fixed marker
   should be added by AIOVY. Check that AIOVY adds no localStorage/cookies or
   patient payloads. Refresh Dashboard, Settings, Profile and Patients.
2. Follow the [current patient-workflow checklist](patient-workflow-audit.md):
   form refresh opens blank; patient-detail refresh returns to Patients; Result,
   SHAP and processing refresh still return to Dashboard. None restores entered
   records or sends a replacement inference request.
3. Check in-app Back from SHAP. Check browser Back/Forward across safe routes,
   transient routes and all six public research examples, including after refresh.
4. Logout using the banner and Profile. Verify the marker disappears, entered
   records clear, and Back/Forward, direct protected URLs and refresh stay gated.
   Include Chrome's full-document Back/Forward cache/session-restore behavior.
5. Block session storage and confirm memory-only messaging. If logout cannot
   remove storage, resolve the warning before continuing. Check independent tabs.
6. Scroll trained and simulated results to the bottom at narrow widths and 200%
   text/zoom. Confirm the entire disclaimer and wrapping action labels can be
   read, including with the demo banner and a device's safe-area inset.

No live Chrome or Android verification is implied by these instructions.

## Files for this change

```text
README.md
docs/security-limitations.md
docs/demo-browser-session.md
ml_model/research_demo/README.md
lib/app.dart
lib/navigation/app_navigator.dart
lib/navigation/route_session.dart
lib/navigation/web_router.dart
lib/navigation/demo_mode_storage.dart
lib/navigation/demo_mode_storage_stub.dart
lib/navigation/demo_mode_storage_web.dart
lib/screens/login/login_screen.dart
lib/screens/assessment/assessment_input_screen.dart
lib/screens/processing/processing_screen.dart
lib/screens/result/result_screen.dart
lib/screens/shap/shap_screen.dart
lib/screens/patient_profile/patient_profile_screen.dart
test/demo_session_test.dart
test/web_router_test.dart
```

Earlier uncommitted informational-screen cleanup, dependency-lock changes and
tracked Python cache changes are outside this change and are preserved.
