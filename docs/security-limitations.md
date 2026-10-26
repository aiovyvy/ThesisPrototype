# AIOVY: security and privacy status

**AIOVY is a thesis research prototype. It is not secure enough for real patient data and is not hospital-ready.**
Use it only with synthetic (made-up) records until proper security engineering, an ethics approval, and the
hospital's own data-protection review are complete.

Last reviewed: 2026-10-21, branch `feature/ui-redesign`.

## 1. What was changed in this review

| Area | Change |
|---|---|
| Backend logs | The API no longer writes vital signs to its error log. A failed SHAP check logs only the size of the mismatch. Any unexpected error is logged by error type only, because library error messages can quote input values. Tests in `ml_model/uci/api/test_api_privacy.py` confirm this, and they fail against the old code, which logged `Age=37.0 SystolicBP=143.0 …`. |
| Demo login | The sign-in screen shows **DEMO ACCESS** and says there is no real authentication. |
| Synthetic data only | The assessment form says not to enter real patient information. The form has no name, address or free-text fields, and patient IDs are generated automatically. |
| Session data | Signing out removes every assessment entered in that session, and only the synthetic demo records remain. Settings → "Clear Session Records" now really does this. It used to show "Local cache cleared" without deleting anything. |
| Simulated vs real predictions | Results from the built-in demo classifier are labelled "Simulated estimate" and "not the trained model" on the result and explanation screens. In API mode, the seeded demo records, which are always simulated, carry a "Simulated" tag in lists. In demo mode, Home and Patients state that every prediction is simulated. Settings → Predictions names the source. |
| API transport | Release builds refuse to send measurements to a non-HTTPS server; nothing is sent. Debug builds still allow `http://` for the local development server. |
| Honest wording | Removed the lock icon from "Data Storage" and the claim that all model outputs are demonstration data, which was false in API mode. |

## 2. API communication review

| # | Risk | Status |
|---|---|---|
| A1 | **No authentication on the API.** Anyone who can reach the server can call `/classify`, `/health` and `/docs`. | **Open.** Needs real user accounts and server-side token checks. Not added: a hard-coded key in the app would be fake security, because anyone can extract it. |
| A2 | **Plain HTTP in development.** Measurements cross the Wi-Fi network unencrypted. | **Partly addressed.** Release builds require HTTPS. Development still uses HTTP, so use synthetic data only. |
| A3 | **The server listens on every network interface** (`--host 0.0.0.0`, needed for phone testing). On shared, guest or university Wi-Fi, other devices can reach it. | **Open.** Run it only on a private network, and use `--host 127.0.0.1` when the phone isn't needed (Chrome or the emulator). |
| A4 | **The API documentation pages are public** (`/docs`, `/openapi.json`). | **Open** (low risk for a prototype). Disable them in any deployed build. |
| A5 | **No rate limiting.** Anyone on the network can send unlimited requests. | **Open.** |
| A6 | **Access log.** Uvicorn records each request's client IP, path and status code. It does not record the request body (the vital signs). | Acceptable for the prototype. Treat the logs as sensitive anyway. |
| A7 | **Validation errors (HTTP 422).** The server's handler already removes the submitted values from the response. | **OK.** Covered by a test. |
| A8 | **CORS** allows only `localhost` browser origins. CORS limits browsers only, so it is not access control. | OK as designed. Not a security measure. |
| A9 | **Release Android builds have no `INTERNET` permission**, so API mode works only in debug builds. | Known. Add the permission only together with HTTPS and authentication. |
| A10 | **Error messages show the server address** (e.g. `http://10.0.2.2:8000`) to the user. | Acceptable for a developer prototype. Remove for real users. |

## 3. Remaining limitations (not fixed)

**Authentication and access**
- Any non-empty email and password signs in. There are no user accounts, roles, session timeout or lockout.
- Web sign-in now enables a clearly labelled, tab-scoped **DEMO-ONLY** marker in `sessionStorage`. It restores UI access after refresh, not identity or records. Anyone can inspect or change it; it is not authentication and is never sent to either API. See [mechanism, limitations and manual checks](demo-browser-session.md).
- The mobile "Remember this workstation" switch remains an in-memory preference. Web instead explains its temporary demo marker and disables credential autofill hints.
- Records show who assessed them as a display name ("Demo Clinician"), not a verified user.

**Data storage**
- All records are kept **in memory only**, unencrypted, and are lost when the app closes. As requested, no database or Firebase was added.
- Sign-out clears only the in-app copy. The app doesn't block screenshots or the recent-apps preview.
- There is no audit log of who viewed or changed a record.

**Clinical and ethical**
- There is no consent flow and no de-identification process. The only safeguard against real data is the instruction to use synthetic data, which is a rule for people and does not stop them technically.
- The trained model has not been clinically validated. All outputs are decision support for research only.

**Operations**
- No dependency vulnerability scan has been run on the Flutter or Python packages.
- No penetration test, threat model or data-protection impact assessment has been done.

## 4. Before any real patient data

At minimum, all of the following are needed:
1. ethics board approval;
2. the hospital's data-protection review;
3. real authentication (accounts, roles, server-side checks);
4. HTTPS everywhere;
5. encrypted storage, if data is kept at all;
6. audit logging;
7. a consent process;
8. a security review by someone independent of the development team.

None of these exist yet.

## 5. How to check

```bash
# Flutter (from the project root)
flutter analyze
flutter test

# Backend privacy tests (from ml_model/uci, after the setup in api/README.md)
.venv\Scripts\python -m unittest api.test_api_privacy -v
```
