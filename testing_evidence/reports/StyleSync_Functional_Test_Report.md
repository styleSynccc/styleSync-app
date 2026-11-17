# StyleSync Functional Testing Report

**Execution date:** 16 November 2026, Asia/Kuala_Lumpur (UTC+08:00). **Build:** working tree at `9526aba52a570018f25ab00618d687099df4e898`; see [integrity audit](../logs/integration/repository_integrity.json). No tracked application, dependency, configuration, rules, or existing test files changed.

## Objectives

Assess the 12 use cases and 36 supplied scenarios against implemented behavior; run and preserve existing tests; add necessary isolated gap checks; collect real evidence; identify remaining manual/integration work. This report does not certify live Firebase or AI integration or Android operation.

## Environment

| Item | Observed |
| --- | --- |
| Host | Windows x64; PowerShell; repository C:/Users/User/styleSync-app |
| Flutter / Dart | 3.44.6 stable / 3.12.2; existing cached dependencies; --no-pub |
| Python / pytest / HTTPX | Project .venv: 3.12.10 / 9.2.0 / 0.28.1 |
| Backend packages | FastAPI 0.141.1; NumPy 2.4.6; OpenCV headless 5.0.0.93; Pillow 12.3.0; MediaPipe 0.10.14; rembg 2.0.77 |
| Firebase CLI | 15.24.0 installed; version check only, no account/project mutation |
| Android | adb installed at SDK path; `adb devices -l` returned an empty list; AVDs Medium_Phone, Pixel_10_Pro_XL, Pixel_7 installed but none connected |
| Local services | 127.0.0.1 ports 8000/8002 closed; common Firebase ports 4000/4400/8080/9099/9199 closed at probe time; emulator routing variables unset |
| Credentials/test project | No dedicated integration account/project/AI credit authorization supplied or used; no credential values inspected |
| Test isolation | FakeEngine, FakeTryOnEngine and fake provider HTTP; mocked token verification; tmp_path backend stores; Firebase fakes and picker/notification method-channel mocks |
| Execution restriction | Windows sandbox startup failed with helper_sandbox_lock_failed; approved elevated read/test commands used |

Evidence: [package/port snapshot](../logs/integration/environment.json), [Flutter version](../logs/flutter/version.log), [Firebase CLI](../logs/firebase/version.log), [devices](../logs/integration/adb_devices.log), [installed AVDs](../logs/integration/android_avds.log). Closed common ports do not prove no service exists at a custom remote endpoint. No remote production endpoint was probed.

## Methodology and status rules

The initial source/test audit and 36-case existing coverage mapping are in [Inspection_and_Test_Plan.md](Inspection_and_Test_Plan.md). All existing Dart and Python tests were read; placeholder assertions were identified. Tests were run from their application roots using existing configuration, then new test files were run separately. Test logs combine full stdout/stderr, with exit code/command/cwd/time stored in adjacent `.meta.json` files. Native JSONL/JUnit results provide per-test outcomes. No assertions were weakened to obtain passes.

**PASS** in the scenario matrix means its stated local negative behavior was actually executed and asserted; only TC-002, TC-006 and TC-008 qualify, at isolated widget/controller scope. **FAIL** would mean an executed original scenario failed its acceptance condition. **BLOCKED** means original mobile/integration acceptance remains incomplete because required device/services/data or agreed behavior are unavailable, even if component checks passed. **NOT RUN** means the original interaction has no matching implemented flow and its proposed replacement was not executed. Partial mocked results are recorded alongside this status and never promoted to an end-to-end PASS. No rows are marked FAIL from inference alone.

Three actual widget PNGs were captured after assertions and visually inspected. They use installed SDK Roboto/Material fonts and an 800x1000 widget surface; they are **not Android screenshots**. The first added run passed but its default Ahem-font captures were unreadable; the `added-readable` rerun supplies the delivered PNGs. Both execution logs remain. The three screenshots show empty/synthetic data only. No manually collected device screenshots exist.

## Automated execution summary

| Run | Passed | Failed | Skipped | Collection errors | Exit | Evidence |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Existing FastAPI tests | 143 | 0 | 0 | 0 | 0 | [full log](../logs/fastapi/baseline.log) · [JUnit](../logs/fastapi/baseline.xml) |
| Existing Flutter tests | 56 | 6 | 0 | 0 | 1 | [full log](../logs/flutter/baseline.log) · [JSONL](../logs/flutter/baseline.jsonl) |
| Added FastAPI gap tests | 6 | 0 | 0 | 0 | 0 | [full log](../logs/fastapi/added.log) · [JUnit](../logs/fastapi/added.xml) |
| Added Flutter gap tests, readable-font run | 11 | 0 | 0 | 0 | 0 | [full log](../logs/flutter/added-readable.log) · [JSONL](../logs/flutter/added-readable.jsonl) |
| **Unique checks across these four runs** | **216** | **6** | **0** | **0** | — | [Automated test inventory](Automated_Test_Inventory.md) |

Automated assertion pass percentage = 216 / 222 × 100 = **97.30%**. This includes the existing nonfunctional `Placeholder test` (1 + 1 = 2); excluding it gives 215 / 221 = **97.29%**. The font rerun repeats the same 11 new Flutter checks and is counted once. The added backend blank-reference characterization passes because it records current behavior; it does not establish suitability rejection. No all-suite rerun was needed: original suites were preserved and additions ran in separate files/processes. The current full Flutter suite remains known failing.

No missing dependencies, skipped tests, or collection errors were observed in these runs. The backend emitted one Starlette TestClient/HTTPX deprecation warning per pytest invocation; dependencies were left unchanged. Global pytest is absent from PATH; `.venv/Scripts/python.exe -m pytest` worked. Flutter dependencies were already cached. `integration_test` is not declared, and no live integration harness was added.

## Scenario acceptance summary

| PASS | FAIL | BLOCKED | NOT RUN | Total |
| ---: | ---: | ---: | ---: | ---: |
| 3 | 0 | 29 | 4 | 36 |

Required-scenario pass percentage = 3 / 36 × 100 = **8.33%**, limited to isolated local validation. **No complete Android/Firebase/real-AI workflow has been accepted.** A pass rate over only the few completed scenarios would hide the outstanding scope and is not used as overall success.

## Test case results and evidence

Each per-case evidence JSON links the exact executed checks that contribute partial coverage, their outcome, and structured log filename. Empty matches explicitly mean no direct automated execution. Source-only findings do not become test passes. Revised expectations in rows with implementation differences are proposals, not silent replacements of the original scenarios.

| Case / use case | Scenario | Expected result / implementation adjustment | Actual observation | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| TC-001 / UC-01 | Register with valid details | Create an Auth user, save profile, and route to setup. | Valid form forwarded all four details to a fake controller. No real account/profile creation was executed. | **BLOCKED** | [TC-001 evidence](../logs/integration/TC-001_evidence.json) |
| TC-002 / UC-01 | Submit empty required fields | Show all required field errors and send no registration call. | Widget submission showed name/email/gender/password errors; fake controller received no registration. Actual widget screenshot captured. | **PASS** | [TC-002 evidence](../logs/integration/TC-002_evidence.json) · [widget PNG](../screenshots/UC-01/TC-002_empty_signup_widget.png) |
| TC-003 / UC-01 | Register using an existing email | Show existing-email error and create no duplicate account. | Real controller displayed a fake Firebase email-already-in-use error and reset loading. Live duplicate-account handling remains unverified. | **BLOCKED** | [TC-003 evidence](../logs/integration/TC-003_evidence.json) |
| TC-004 / UC-02 | Login using valid credentials | Authenticate and route to Home for a completed profile, otherwise setup. | Valid form forwarded credentials to a fake controller. No live Firebase login or profile-based routing executed. | **BLOCKED** | [TC-004 evidence](../logs/integration/TC-004_evidence.json) |
| TC-005 / UC-02 | Login using incorrect password | Show authentication error, stop loading, and stay signed out. | Real controller handled a fake wrong-password exception, retained the original screen, and stopped loading. Live Firebase behavior unverified. | **BLOCKED** | [TC-005 evidence](../logs/integration/TC-005_evidence.json) |
| TC-006 / UC-02 | Login using empty fields | Show email/password required errors and send no login call. | Both field errors appeared on submit and the isolated controller received no credentials. Actual widget screenshot captured. | **PASS** | [TC-006 evidence](../logs/integration/TC-006_evidence.json) · [widget PNG](../screenshots/UC-02/TC-006_empty_login_widget.png) |
| TC-007 / UC-03 | Create Digital Twin with valid body details | Process body photo, save positive metrics/style/twin references, then open Home. | Existing fake photo pipeline saved four temporary artifacts at 768x1024; metric helpers pass. No real models/Firebase profile save executed. | **BLOCKED** | [TC-007 evidence](../logs/integration/TC-007_evidence.json) |
| TC-008 / UC-03 | Submit incomplete body details | Reject missing photo or incomplete metrics before file, API, or Firebase work. | Widget rejected absent photo; controller rejected empty height even with an image reference. Existing helper tests reject empty/nonfinite/nonpositive values. Local negative scope only. | **PASS** | [TC-008 evidence](../logs/integration/TC-008_evidence.json) · [widget PNG](../screenshots/UC-03/TC-008_missing_photo_widget.png) |
| TC-009 / UC-03 | Retrieve saved Digital Twin | Retrieve the signed-in user's saved processed twin or documented Firebase photo fallback. | Temporary-store list tests returned newest-first owned twins; no mobile retrieval or persisted Firebase photo fallback was executed. | **BLOCKED** | [TC-009 evidence](../logs/integration/TC-009_evidence.json) |
| TC-010 / UC-04 | Upload clothing image from gallery | Process selected clothing, store image and clothes record, and refresh closet. | Wardrobe API processed synthetic image using FakeEngine; link recovery tests pass. OS gallery and Firebase upload were not exercised. | **BLOCKED** | [TC-010 evidence](../logs/integration/TC-010_evidence.json) |
| TC-011 / UC-04 | Capture clothing image using camera | Open permitted camera, accept captured photo, and add processed item. | Camera source wiring was found in code; no connected Android device and no camera capture executed. | **BLOCKED** | [TC-011 evidence](../logs/integration/TC-011_evidence.json) |
| TC-012 / UC-04 | Cancel clothing image selection | Return safely without new clothing, storage object, or processing request. | Code returns when picker result is null; clothing cancellation was not executed because ClosetController initializes live Firebase singletons. | **BLOCKED** | [TC-012 evidence](../logs/integration/TC-012_evidence.json) |
| TC-013 / UC-05 | Assign clothing category | Use category chosen before upload and persist matching category/item reference. | API category assignment/style checks pass; missing category returns 422 and saves nothing. Mobile category-first flow and Firebase persistence unverified. | **BLOCKED** | [TC-013 evidence](../logs/integration/TC-013_evidence.json) |
| TC-014 / UC-05 | Change clothing category | Original: edit saved item category. Proposed: dismiss and choose another category before upload. | No saved-item category editing operation was found in UI/controller or FastAPI routes. Proposed pre-upload replacement was not executed. | **NOT RUN** | [TC-014 evidence](../logs/integration/TC-014_evidence.json) |
| TC-015 / UC-05 | Cancel categorization | Dismiss category selection without saving or processing an item. | Category selection is a bottom sheet before upload; no separate categorization transaction. Dismissal behavior was not executed. | **BLOCKED** | [TC-015 evidence](../logs/integration/TC-015_evidence.json) |
| TC-016 / UC-06 | Generate Virtual Try-On image | Confirm mode/cost, generate selected outfit on owned twin, display resulting image. | Fake API generation/composition and provider payload tests pass. Six existing confirmation-widget tests fail because credit totals are absent. No live AI generation executed. | **BLOCKED** | [TC-016 evidence](../logs/integration/TC-016_evidence.json) |
| TC-017 / UC-06 | Change clothing selection before generation | Generate only the final selected item IDs, without an earlier unconfirmed request. | Existing HTTP mock asserts a fixed item list, not UI selection changes. No running selection flow executed. | **BLOCKED** | [TC-017 evidence](../logs/integration/TC-017_evidence.json) |
| TC-018 / UC-06 | Attempt Virtual Try-On without Digital Twin | Disable generation with setup guidance; reject unknown twin in API. | API returned 404 TWIN_NOT_FOUND for an unknown twin with a fake engine. VTON empty-twin UI was not executed. | **BLOCKED** | [TC-018 evidence](../logs/integration/TC-018_evidence.json) |
| TC-019 / UC-07 | Save generated outfit | Upload generated image and add exactly one likedOutfits record, visible in My Outfits. | OutfitDraft injected persistence callback and backend temporary result persistence passed. Neither proves actual Firebase saving. | **BLOCKED** | [TC-019 evidence](../logs/integration/TC-019_evidence.json) |
| TC-020 / UC-07 | Cancel saving | Original: cancel save dialog. Proposed: leave without tapping Save, with no likedOutfits write. | Save acts immediately; no cancel-save dialog exists. Leaving unsaved does not remove the backend generation result already persisted. | **NOT RUN** | [TC-020 evidence](../logs/integration/TC-020_evidence.json) |
| TC-021 / UC-07 | Save an already saved outfit | Repeated taps on the current saved draft do not create duplicate uploads/documents. | Draft test proves one injected persist call across concurrent and repeated saves. Cross-session/content-hash deduplication is not implemented or claimed. | **BLOCKED** | [TC-021 evidence](../logs/integration/TC-021_evidence.json) |
| TC-022 / UC-08 | Upload valid inspiration image | Preview selected image locally; upload only on confirmed generation with a saved twin. | Multipart mock and fake inspo endpoint pass. Selection is local; standalone upload is not an API operation. | **BLOCKED** | [TC-022 evidence](../logs/integration/TC-022_evidence.json) |
| TC-023 / UC-08 | Upload unsupported image format | Reject undecodable/unsupported reference before provider call or result persistence. | Real in-process API rejected SVG with 400 INVALID_IMAGE and zero fake-provider calls. Device picker support/rejection remains unexecuted; no strict extension allowlist exists. | **BLOCKED** | [TC-023 evidence](../logs/integration/TC-023_evidence.json) |
| TC-024 / UC-08 | Cancel image selection | Cancel OS gallery without changing reference or starting generation. | Mocked picker returned null; widget retained empty selection and issued no generation. Actual Android picker cancellation was not executed. | **BLOCKED** | [TC-024 evidence](../logs/integration/TC-024_evidence.json) |
| TC-025 / UC-09 | Apply inspiration style to Digital Twin | Transfer visible reference outfit to selected twin, preserving expected identity and returning a usable image. | Fake provider returned JPEG and metadata; mocked hosted payload contains identity prompt. Real style/identity/garment quality was not measured. | **BLOCKED** | [TC-025 evidence](../logs/integration/TC-025_evidence.json) |
| TC-026 / UC-09 | Apply style without Digital Twin | Show setup guidance/disabled Generate; API rejects absent or other-user twin before provider. | Existing fake UI disabled Generate for empty twins; added API test returned 404 for absent twin, zero provider calls and no result directory. Real account flow unverified. | **BLOCKED** | [TC-026 evidence](../logs/integration/TC-026_evidence.json) |
| TC-027 / UC-09 | Process an unsuitable inspiration image | Reject malformed/undersized inputs locally; define desired handling for valid-sized non-outfit scenes. | Tiny reference returned 400 before provider. Valid-sized flat blank JPEG returned 201 and called fake provider once. Semantic suitability is not checked locally; real provider response and acceptance criteria remain unresolved. | **BLOCKED** | [TC-027 evidence](../logs/integration/TC-027_evidence.json) |
| TC-028 / UC-10 | Schedule outfit for selected date | Save closet items for a future local date/time and report actual reminder scheduling status. | Model and mocked notification tests pass, including Kuala Lumpur time and permission fallbacks. No Firestore plan save or Android alarm delivery executed. | **BLOCKED** | [TC-028 evidence](../logs/integration/TC-028_evidence.json) |
| TC-029 / UC-10 | Change selected date | Use final chosen date before commit. Moving an already saved plan has no dedicated action. | Date/time picker and one-document-per-date save inspected; no date-change interaction executed. | **BLOCKED** | [TC-029 evidence](../logs/integration/TC-029_evidence.json) |
| TC-030 / UC-10 | Cancel outfit scheduling | Cancel date picker, time picker, or item sheet without saving a plan or alarm. | Null date/time returns and sheet-before-save sequence inspected; no UI cancellation was executed. | **BLOCKED** | [TC-030 evidence](../logs/integration/TC-030_evidence.json) |
| TC-031 / UC-11 | View scheduled outfit | Show upcoming dated card and its closet-item thumbnails; past plan remains in My Outfits. | Upcoming/legacy expiry and gallery conversion unit checks pass; preview renders item collage. No real plan stream displayed. | **BLOCKED** | [TC-031 evidence](../logs/integration/TC-031_evidence.json) |
| TC-032 / UC-11 | View date with no scheduled outfit | Original: daily-date empty state. Proposed: empty Upcoming Outfits list. | Planner has no selected-day viewing/calendar control. Empty-list text is implemented, but original daily-date flow is unavailable and not executed. | **NOT RUN** | [TC-032 evidence](../logs/integration/TC-032_evidence.json) |
| TC-033 / UC-11 | Switch between planned dates | Original: daily calendar navigation. Proposed: inspect multiple dated upcoming cards or browse saved planner pages. | No daily calendar selector exists. Multiple list cards and My Outfits page browsing are available; revised behavior not executed. | **NOT RUN** | [TC-033 evidence](../logs/integration/TC-033_evidence.json) |
| TC-034 / UC-12 | Display outfit on Digital Twin | Display the generated outfit-on-twin image and reopen its saved result; planner item collage remains distinct. | VTON/Inspo result display and saved-image viewer exist in source; fake try-on returns image data. No complete result display executed. If this means dressing a twin from a saved planner outfit, that separate operation is absent and needs clarification. | **BLOCKED** | [TC-034 evidence](../logs/integration/TC-034_evidence.json) |
| TC-035 / UC-12 | Display outfit without Digital Twin | Show create-twin guidance before generation; viewing an existing saved image can remain independent of a current twin. | Isolated no-twin generation guards pass; Virtual Twin empty state exists in source. Full no-twin viewer/navigation behavior was not executed. The intended display entry point needs confirmation before accepting this scenario. | **BLOCKED** | [TC-035 evidence](../logs/integration/TC-035_evidence.json) |
| TC-036 / UC-12 | Display unavailable outfit | Show a safe missing-image state for absent/unavailable saved outfit image, with no crash. | Two added widget tests passed for missing generated-image URL: thumbnail icon and readable detail message. Missing remote object/document and Android full viewer not exercised. | **BLOCKED** | [TC-036 evidence](../logs/integration/TC-036_evidence.json) |

Machine-readable mapping: [Coverage_Mapping.csv](Coverage_Mapping.csv), [test_cases.json](test_cases.json). Initial existing-test mapping remains in the inspection plan; final added-test mapping and full node names are in each case evidence file and the inventory.

## Findings and differences from requirements

**D-001 — generation confirmation regression/test-contract mismatch.** Six existing tests fail in `test/generation_confirmation_test.dart`. The actual `confirmGeneration` widget uses title `Generate outfit?`, a generic `Generate` button, and no displayed total. Tests expect `Generate for N credits?`, credit-bearing button text, and the earlier-steps credit notice. The first failing assertion is the missing title in all six cases; later assertions in those tests did not execute. Source confirms the additional missing text. This affects confidence in cost disclosure before TC-016/025 generation, but does not prove live generation itself fails. The API still receives/checks confirmed credits and those mocked tests pass. Resolve the intended cost-disclosure requirement and, if retained, restore the display after approval; do not weaken the existing tests merely to turn them green.

Failing test names:

- `generation_confirmation_test.dart::VTON shows the total and cancellation declines generation`
- `generation_confirmation_test.dart::Inspo confirms exactly one three-credit generation`
- `generation_confirmation_test.dart::cost confirmation remains usable in landscape`
- `generation_confirmation_test.dart::Fast confirmation shows its own total`
- `generation_confirmation_test.dart::Balanced confirmation shows its own total`
- `generation_confirmation_test.dart::Quality confirmation shows its own total`

**G-002 — inspiration suitability limitation.** Added TC027 probe sent an actual flat 600x800 JPEG to the in-process API. It returned 201 and invoked the fake provider once; a 120x160 JPEG returned 400 without a call. There is no local person/outfit suitability classifier. This is an observed API behavior and a requirement gap, not proof of what the real hosted provider would return. Agree acceptable behavior for non-person scenes, multiple people, occlusion and unclear outfits before accepting TC-027.

**G-003 — four interactions require a revised interpretation.** TC-014 has no saved category edit; TC-020 has no save-cancel dialog; TC-032/033 have no daily calendar. Proposed replacements are explicitly shown in the matrix and manual guide. TC-034/035 are treated as blocked display scenarios, since generated-result viewing and empty-twin guidance exist; if the intended requirement is applying a saved/planned outfit to a twin, that separate operation is absent. TC-029 supports changing a date before commit, not moving an existing plan. Categories precede upload (TC-013/015); inspiration selection is local until Generate (TC-022). Saved generated images can be viewed independently of a current twin.

**G-004 — save and schedule scope.** Draft guards deduplicate the current result in memory, not across sessions or identical image content. Backend generation results persist before explicit Firebase Save; leaving unsaved only avoids `likedOutfits`. Planner stores one document per local date, so a later same-day save replaces that date's plan; it displays upcoming cards and archives past plans in My Outfits. Notification mocks verify payloads, not actual Android delivery.

**E-001 — integration prerequisites unavailable.** No connected device; default local AI/worker/emulator ports closed; no supplied dedicated test Firebase environment or live AI authorization. Although Firebase project configuration exists, it was not used to mutate accounts/data. The mobile API URL defaults to a particular LAN address; an approved test build must override it for the actual host/device arrangement. Source security rules were read, not deployed or behavior-tested.

## Added tests

- `apps/mobile_app/test/fyp_functional_gaps_test.dart`: 11 distinct checks covering empty/valid form submission, mocked Firebase failures, missing/incomplete setup, picker-null cancellation, missing-image fallback; three widget captures. Existing tests left untouched.
- `apps/ai_service/tests/test_fyp_functional_gaps.py`: 6 checks covering missing file/category fields, absent inspiration twin, SVG rejection, low-resolution rejection, and blank-image characterization; temporary data and fake provider only.

## Reproduction and evidence handling

From repository root, use the project venv to run `testing_evidence/tools/run_qa.py`. Actions are `environment`, `python-baseline`, `flutter-baseline`, `python-added`, and `flutter-added`. Use `--label rerun_YYYYMMDD` for new run filenames; existing baseline log files must be preserved. `flutter test` runs inside `apps/mobile_app` with `--no-pub`; pytest inside `apps/ai_service` reads `pytest.ini`. The runner's own shell exit is not the test exit: consult `.meta.json` and structured results (Flutter baseline test exit 1).

Reports and evidence can be packaged without Firebase credentials. Logs redact bearer values, JWTs, tokenized URLs and matching sensitive environment values. All tests use synthetic data, fake credentials and temporary stores. No passwords/tokens/keys were copied from user configuration. Do not commit future manual screenshots containing personal accounts or full Firebase download URLs. [Evidence manifest](Evidence_Manifest.json) records SHA-256 hashes; `.gitignore` inside the evidence folder keeps sanitized `.log` files from being lost to the root ignore rule.

## Limitations and conclusion

Android camera/gallery/permission interaction, live registration/login/profile/Storage persistence, deployed Firebase rules, real MediaPipe/background removal/extraction models, hosted AI quality and failure behavior, and delivered reminders remain unverified. Mocked images/provider responses are not AI output evidence. No UI image was fabricated; empty screenshot folders for other use cases are intentional. Exact manual procedures and proposed replacements are in [Manual_Testing_Guide.md](Manual_Testing_Guide.md).

Automated testing found six real failing test assertions, all around missing confirmation cost text, while the isolated backend suite passed. Only three of 36 original scenarios have completed local acceptance checks. Complete functional acceptance requires resolving the stated requirement differences and executing the blocked scenarios in an approved dedicated test environment. **100% functional success is not claimed.**
